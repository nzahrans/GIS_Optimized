import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user_home.dart';
import 'admin_home.dart';
import '../utils/date_formatter.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;
  final bool isAdmin;

  const SearchResultsPage({super.key, required this.query, this.isAdmin = false});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late String _currentQuery;
  late TextEditingController _searchController;
  final Future<QuerySnapshot> _wargaFuture =
      FirebaseFirestore.instance.collection('warga').get();

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white.withOpacity(0.6) : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Cari warga...",
                hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                prefixIcon: Icon(Icons.search, color: subTextColor, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _currentQuery = "";
                          });
                        },
                        child: Icon(Icons.clear, color: subTextColor, size: 18),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 1.8,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _currentQuery = value;
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _currentQuery = value.trim();
                });
              },
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
            height: 1.0,
          ),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _wargaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Terjadi kesalahan saat memuat data', style: TextStyle(color: textColor)),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Text('Data tidak tersedia', style: TextStyle(color: textColor)),
            );
          }

          final allDocs = snapshot.data!.docs;

          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final nama = (data['nama'] ?? '').toString().toLowerCase();
            final nik = (data['nik'] ?? '').toString().toLowerCase();
            final blok = (data['blok'] ?? '').toString().toLowerCase();
            final search = _currentQuery.toLowerCase().trim();

            return nama.contains(search) || nik.contains(search) || blok.contains(search);
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_outlined,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Data Tidak Ditemukan",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada data warga yang cocok dengan pencarian "$_currentQuery". Silakan periksa kembali kata kunci Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text(
                          "Kembali ke Beranda",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.find_in_page_outlined,
                      size: 20,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Menampilkan ${filteredDocs.length} data warga yang cocok',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String nama = data['nama'] ?? 'Tanpa Nama';
                    String blok = data['blok'] ?? '';
                    String nik = data['nik'] ?? '';
                    String statusCair = data['status_cair'] ?? '';
                    String fotoUrl = data['foto_url'] ?? '';

                    return GestureDetector(
                      onTap: () => _showDetailBottomSheet(context, data, doc.id),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar / Foto (Hanya dimuat jika Admin)
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isDark ? const Color(0xFF090D16) : Colors.grey[200],
                                image: (widget.isAdmin && fotoUrl.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(fotoUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (!widget.isAdmin || fotoUrl.isEmpty)
                                  ? Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: widget.isAdmin
                                              ? [Colors.red[400]!, Colors.red[700]!]
                                              : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),

                            // Info Warga
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (blok.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.blue.withOpacity(0.1)),
                                          ),
                                          child: Text(
                                            "Blok $blok",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white.withOpacity(0.7) : Colors.blue[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (widget.isAdmin && nik.isNotEmpty) ...[
                                        Text(
                                          "NIK $nik",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (widget.isAdmin && statusCair.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _statusBadge(statusCair),
                                  ]
                                ],
                              ),
                            ),

                            // Arrow icon
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
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
      ),
    );
  }

  Widget _statusBadge(String status) {
    final bool isCair = status == 'Sudah Menerima';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCair ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCair ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCair ? Icons.check_circle : Icons.pending,
            size: 12,
            color: isCair ? Colors.green : Colors.amber[700],
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCair ? Colors.green : Colors.amber[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailBottomSheet(BuildContext context, Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        final nama = data['nama'] ?? 'Tanpa Nama';
        final nik = data['nik'] ?? '';
        final noKk = data['no_kk'] ?? '';
        final blok = data['blok'] ?? '';
        final menerimaBantuan = data['menerima_bantuan'] ?? 'Tidak';
        final jenisBantuan = data['jenis_bantuan'] ?? '';
        final statusCair = data['status_cair'] ?? '';
        final fotoUrl = data['foto_url'] ?? '';
        final lokasi = data['lokasi'] as GeoPoint?;

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Warga
                  Text(
                    nama,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Text(
                    "Detail Data Kependudukan",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Divider(height: 24),

                  // Data Utama
                  const Text(
                    "DATA WARGA",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.isAdmin) ...[
                    _profileRow("NIK", nik, isDark),
                    _profileRow("No. KK", noKk, isDark),
                  ],
                  _profileRow("Blok/Gang", blok, isDark),
                  const SizedBox(height: 20),

                  // Data Bansos (Hanya Tampil untuk Admin)
                  if (widget.isAdmin) ...[
                    const Text(
                      "STATUS BANTUAN SOSIAL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: menerimaBantuan == 'Ya'
                            ? Colors.green.withOpacity(isDark ? 0.1 : 0.05)
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: menerimaBantuan == 'Ya'
                              ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      child: Column(
                        children: [
                          _profileRow("Penerima Bantuan", menerimaBantuan, isDark),
                          if (menerimaBantuan == 'Ya') ...[
                            const Divider(height: 16),
                            _profileRow("Jenis Bantuan", jenisBantuan, isDark),
                            _profileRow("Status Pencairan", statusCair, isDark),
                            if (statusCair == 'Sudah Menerima' &&
                                data['tanggal_diterima'] != null)
                              _profileRow(
                                "Waktu Diterima",
                                DateFormatter.formatIndonesianDate(data['tanggal_diterima']),
                                isDark,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Foto Rumah (Hanya Tampil untuk Admin)
                  if (widget.isAdmin) ...[
                    if (fotoUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                          image: DecorationImage(
                            image: NetworkImage(fotoUrl),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 36, color: isDark ? Colors.white30 : Colors.grey),
                            const SizedBox(height: 8),
                            Text("Foto rumah tidak tersedia", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],

                  // Aksi
                  Row(
                    children: [
                      if (lokasi != null) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text(
                              "Lihat di Peta",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Tutup Bottom Sheet
                              LatLng targetLocation = LatLng(lokasi.latitude, lokasi.longitude);

                              if (widget.isAdmin) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminHomePage(
                                      centerOnLocation: targetLocation,
                                      highlightDocId: docId,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              } else {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserHomePage(
                                      centerOnLocation: targetLocation,
                                      highlightDocId: docId,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Tutup",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileRow(String label, dynamic value, bool isDark) {
    if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}