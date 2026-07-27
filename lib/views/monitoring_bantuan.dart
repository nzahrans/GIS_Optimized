import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/warga_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/bantuan_status_badge.dart';
import '../utils/date_formatter.dart';

class MonitoringBantuanPage extends StatefulWidget {
  const MonitoringBantuanPage({super.key});

  @override
  State<MonitoringBantuanPage> createState() => _MonitoringBantuanPageState();
}

class _MonitoringBantuanPageState extends State<MonitoringBantuanPage> {
  String _searchQuery = "";
  String _statusFilter = "Semua";
  String _programFilter = "Semua";
  final _searchController = TextEditingController();
  final Set<String> _selectedBantuanIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wargaProvider = Provider.of<WargaProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Monitoring Bantuan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getWargaStream(),
        builder: (context, wargaSnapshot) {
          if (wargaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (wargaSnapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${wargaSnapshot.error}"));
          }

          final wargaDocs = wargaSnapshot.data?.docs ?? [];
          final Map<String, Map<String, dynamic>> wargaMap = {};
          for (var doc in wargaDocs) {
            wargaMap[doc.id] = doc.data() as Map<String, dynamic>;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getAllBantuanAktifStream(),
            builder: (context, bantuanSnapshot) {
              if (bantuanSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final bantuanDocs = bantuanSnapshot.data?.docs ?? [];

              // Bangun list item bantuan lengkap dengan info warga
              final List<Map<String, dynamic>> items = [];
              final Set<String> programNames = {"Semua"};

              for (var doc in bantuanDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final String idBantuan = doc.id;
                final String wargaDocId = doc.reference.parent.parent!.id;
                final wargaData = wargaMap[wargaDocId];

                if (wargaData == null) continue;

                final String jenis = data['jenis_bantuan'] ?? '-';
                // Masukkan nama program unik ke filter set
                final cleanJenis = jenis.split(' ').first.toUpperCase();
                if (cleanJenis.isNotEmpty && cleanJenis != '-') {
                  programNames.add(cleanJenis);
                }

                // Ambil info detail
                final String nama = wargaData['nama'] ?? '';
                final String blok = wargaData['blok'] ?? '-';
                final String status = data['status_cair'] ?? 'Belum Menerima';
                final Timestamp? tglPencairan = data['tanggal_pencairan'];

                items.add({
                  'id': idBantuan,
                  'wargaDocId': wargaDocId,
                  'nama': nama,
                  'blok': blok,
                  'jenis': jenis,
                  'cleanJenis': cleanJenis,
                  'status': status,
                  'tanggalPencairan': tglPencairan != null ? tglPencairan.toDate() : null,
                  'dikonfirmasi': data['dikonfirmasi_warga'] ?? false,
                  'tanggalKonfirmasi': data['tanggal_konfirmasi'] != null ? (data['tanggal_konfirmasi'] as Timestamp).toDate() : null,
                });
              }

              // Filter Item
              final filteredItems = items.where((item) {
                // Filter Pencarian Nama
                final matchesSearch = item['nama'].toLowerCase().contains(_searchQuery.toLowerCase());

                // Filter Status Cair
                bool matchesStatus = true;
                if (_statusFilter == "Belum Cair") {
                  matchesStatus = item['status'] == 'Belum Menerima';
                } else if (_statusFilter == "Sudah Cair") {
                  matchesStatus = item['status'] == 'Sudah Menerima';
                } else if (_statusFilter == "Dikonfirmasi") {
                  matchesStatus = item['status'] == 'Dikonfirmasi Warga';
                }

                // Filter Program
                bool matchesProgram = true;
                if (_programFilter != "Semua") {
                  matchesProgram = item['cleanJenis'] == _programFilter;
                }

                return matchesSearch && matchesStatus && matchesProgram;
              }).toList();

              // Bersihkan set pilihan yang ter-filter keluar
              final filteredIds = filteredItems.map((e) => e['id'] as String).toSet();
              _selectedBantuanIds.retainAll(filteredIds);

              // Cek apakah semua item belum cair terpilih untuk bulk action
              final belumCairItems = filteredItems.where((e) => e['status'] == 'Belum Menerima').toList();
              final bool isAllSelected = belumCairItems.isNotEmpty &&
                  belumCairItems.every((item) => _selectedBantuanIds.contains(item['id']));

              return Column(
                children: [
                  // Form Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: "Cari Nama Penerima",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = "";
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: const InputDecoration(labelText: "Status Penyaluran"),
                                items: ["Semua", "Belum Cair", "Sudah Cair", "Dikonfirmasi"]
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _statusFilter = val!;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _programFilter,
                                decoration: const InputDecoration(labelText: "Program Bantuan"),
                                items: programNames
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _programFilter = val!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bulk Actions Bar
                  if (_selectedBantuanIds.isNotEmpty)
                    Container(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_selectedBantuanIds.length} bansos terpilih",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text("Cairkan Terpilih", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: wargaProvider.isLoading
                                ? null
                                : () async {
                                    // Proses pencairan massal
                                    int successCount = 0;
                                    final List<String> toProcess = List.from(_selectedBantuanIds);
                                    
                                    for (var id in toProcess) {
                                      // Cari item detail untuk mendapatkan wargaDocId
                                      final item = filteredItems.firstWhere((e) => e['id'] == id);
                                      final success = await wargaProvider.updateBantuanStatus(
                                        item['wargaDocId'],
                                        id,
                                        'Sudah Menerima',
                                      );
                                      if (success) successCount++;
                                    }

                                    if (mounted) {
                                      setState(() {
                                        _selectedBantuanIds.clear();
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("$successCount Bantuan berhasil dicairkan!"),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),

                  // Data Table List
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(child: Text("Tidak ada data monitoring bantuan.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final String idBantuan = item['id'];
                              final String wargaDocId = item['wargaDocId'];
                              final String nama = item['nama'];
                              final String blok = item['blok'];
                              final String jenis = item['jenis'];
                              final String status = item['status'];
                              final isSelected = _selectedBantuanIds.contains(idBantuan);

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      // Checkbox jika statusnya Belum Cair
                                      if (status == 'Belum Menerima')
                                        Checkbox(
                                          activeColor: theme.colorScheme.primary,
                                          value: isSelected,
                                          onChanged: (bool? val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedBantuanIds.add(idBantuan);
                                              } else {
                                                _selectedBantuanIds.remove(idBantuan);
                                              }
                                            });
                                          },
                                        )
                                      else
                                        const SizedBox(width: 8),
                                      
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nama,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ),
                                                BantuanStatusBadge(status: status),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              "Alamat: $blok  |  Bansos: $jenis",
                                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            ),
                                            const SizedBox(height: 4),
                                            if (status == 'Sudah Menerima' && item['tanggalPencairan'] != null)
                                              Text(
                                                "Dicairkan: ${DateFormatter.formatIndonesianDate(item['tanggalPencairan'])}",
                                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                                              )
                                            else if (status == 'Dikonfirmasi Warga' && item['tanggalKonfirmasi'] != null)
                                              Text(
                                                "Diterima Warga: ${DateFormatter.formatIndonesianDate(item['tanggalKonfirmasi'])}",
                                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Tombol aksi Cairkan cepat jika statusnya Belum Cair
                                      if (status == 'Belum Menerima')
                                        IconButton(
                                          icon: const Icon(Icons.payment, color: Colors.orange),
                                          tooltip: "Cairkan Bansos",
                                          onPressed: wargaProvider.isLoading
                                              ? null
                                              : () async {
                                                  final success = await wargaProvider.updateBantuanStatus(
                                                    wargaDocId,
                                                    idBantuan,
                                                    'Sudah Menerima',
                                                  );
                                                  if (mounted) {
                                                    if (success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text("Bantuan berhasil dicairkan!"),
                                                          backgroundColor: Colors.green,
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(wargaProvider.errorMessage ?? "Gagal mencairkan bantuan"),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
