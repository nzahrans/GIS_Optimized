import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user_home.dart';
import 'admin_home.dart';

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
  
  late final Future<List<QuerySnapshot>> _searchFuture;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
    _searchFuture = Future.wait([
      FirebaseFirestore.instance.collection('warga').get(),
      FirebaseFirestore.instance.collectionGroup('anggota_keluarga').get(),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
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
      body: FutureBuilder<List<QuerySnapshot>>(
        future: _searchFuture,
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

          if (!snapshot.hasData || snapshot.data!.length < 2) {
            return Center(
              child: Text('Data tidak tersedia', style: TextStyle(color: textColor)),
            );
          }

          final wargaDocs = snapshot.data![0].docs;
          final anggotaDocs = snapshot.data![1].docs;
          
          final List<Map<String, dynamic>> combinedResults = [];
          final search = _currentQuery.toLowerCase().trim();

          // 1. Filter warga (KK)
          for (var doc in wargaDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final nama = (data['nama'] ?? '').toString().toLowerCase();
            final nik = (data['nik'] ?? '').toString().toLowerCase();
            final blok = (data['blok'] ?? '').toString().toLowerCase();

            if (nama.contains(search) || nik.contains(search) || blok.contains(search)) {
              combinedResults.add({
                'isAnggota': false,
                'id': doc.id,
                'nama': data['nama'] ?? 'Tanpa Nama',
                'blok': data['blok'] ?? '',
                'nik': data['nik'] ?? '',
                'foto_url': data['foto_url'] ?? '',
                'status_cair': data['status_cair'] ?? '',
                'menerima_bantuan': data['menerima_bantuan'] ?? 'Tidak',
                'lokasi': data['lokasi'],
                'parentDocId': doc.id,
                'parentData': data,
              });
            }
          }

          // 2. Filter anggota keluarga
          for (var doc in anggotaDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final nama = (data['nama'] ?? '').toString().toLowerCase();
            final nik = (data['nik'] ?? '').toString().toLowerCase();

            if (nama.contains(search) || nik.contains(search)) {
              String parentDocId = '';
              String parentName = 'Tidak diketahui';
              Map<String, dynamic>? parentData;
              final parentId = doc.reference.parent.parent?.id;
              
              if (parentId != null) {
                try {
                  final parentDoc = wargaDocs.firstWhere((w) => w.id == parentId);
                  parentDocId = parentDoc.id;
                  parentData = parentDoc.data() as Map<String, dynamic>?;
                  parentName = parentData?['nama'] ?? 'Tidak diketahui';
                } catch (_) {}
              }

              combinedResults.add({
                'isAnggota': true,
                'id': doc.id,
                'nama': data['nama'] ?? 'Tanpa Nama',
                'blok': parentData?['blok'] ?? '',
                'nik': data['nik'] ?? '',
                'foto_url': parentData?['foto_url'] ?? '',
                'status_cair': parentData?['status_cair'] ?? '',
                'menerima_bantuan': parentData?['menerima_bantuan'] ?? 'Tidak',
                'lokasi': parentData?['lokasi'],
                'parentDocId': parentDocId,
                'parentData': parentData,
                'hubungan': data['hubungan'] ?? 'Anggota',
                'parentKkName': parentName,
              });
            }
          }

          if (combinedResults.isEmpty) {
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
                      'Menampilkan ${combinedResults.length} hasil yang cocok',
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
                  itemCount: combinedResults.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final suggestion = combinedResults[index];
                    final isAnggota = suggestion['isAnggota'] as bool;
                    final nama = suggestion['nama'] as String;
                    final blok = suggestion['blok'] as String;
                    final nik = suggestion['nik'] as String;
                    final statusCair = suggestion['status_cair'] as String;
                    final menerimaBantuan = suggestion['menerima_bantuan'] as String? ?? 'Tidak';
                    final fotoUrl = suggestion['foto_url'] as String;

                    return GestureDetector(
                      onTap: () {
                        GeoPoint? lokasi = suggestion['lokasi'] as GeoPoint?;
                        if (lokasi != null) {
                          LatLng targetLocation = LatLng(lokasi.latitude, lokasi.longitude);
                          if (widget.isAdmin) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminHomePage(
                                  centerOnLocation: targetLocation,
                                  highlightDocId: suggestion['parentDocId'],
                                  highlightAnggotaId: isAnggota ? suggestion['id'] : null,
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
                                  highlightDocId: suggestion['parentDocId'],
                                  highlightAnggotaId: isAnggota ? suggestion['id'] : null,
                                ),
                              ),
                              (route) => false,
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Lokasi warga tidak tersedia"),
                            ),
                          );
                        }
                      },
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
                                          colors: isAnggota
                                              ? [Colors.purple[400]!, Colors.purple[700]!]
                                              : (widget.isAdmin
                                                  ? [Colors.red[400]!, Colors.red[700]!]
                                                  : [const Color(0xFF3B82F6), const Color(0xFF2563EB)]),
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(
                                        isAnggota ? Icons.people_outline : Icons.person_outline,
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
                                  const SizedBox(height: 4),
                                  if (isAnggota) ...[
                                    Text(
                                      "${suggestion['hubungan']} • KK: ${suggestion['parentKkName']}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
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
                                        Expanded(
                                          child: Text(
                                            "NIK $nik",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (widget.isAdmin && menerimaBantuan == 'Ya' && statusCair.isNotEmpty) ...[
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
}