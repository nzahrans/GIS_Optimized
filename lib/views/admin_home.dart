import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'form_warga.dart';
import 'search_results.dart';
import 'login_page.dart';
import '../providers/auth_provider.dart';
import '../providers/map_provider.dart';
import '../providers/warga_provider.dart';
import '../widgets/warga_info_sheet.dart';

class AdminHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;

  const AdminHomePage({super.key, this.centerOnLocation, this.highlightDocId});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String? _selectedDocId;
  bool _isDashboardExpanded = false;
  String? _activeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSuggestionsList(BuildContext context, List<DocumentSnapshot> docs, bool isAdminPage) {
    final query = _searchQuery.toLowerCase().trim();
    final suggestions = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final nama = (data['nama'] ?? '').toString().toLowerCase();
      final nik = (data['nik'] ?? '').toString().toLowerCase();
      final blok = (data['blok'] ?? '').toString().toLowerCase();
      return nama.contains(query) ||
          nik.contains(query) ||
          blok.contains(query);
    }).toList();

    if (suggestions.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.search_off, color: Colors.grey),
        title: Text("Tidak ada hasil cocok", style: TextStyle(color: Colors.grey)),
      );
    }

    final displayList = suggestions.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayList.length + (suggestions.length > 5 ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return ListTile(
            dense: true,
            tileColor: const Color(0xFFF8FAFC),
            title: Text(
              "Lihat semua hasil untuk '$_searchQuery'...",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF1E3A8A)),
            onTap: () {
              final searchVal = _searchQuery;
              _searchController.clear();
              setState(() {
                _searchQuery = "";
              });
              FocusScope.of(context).unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(
                    query: searchVal,
                    isAdmin: isAdminPage,
                  ),
                ),
              );
            },
          );
        }

        final doc = displayList[index];
        final data = doc.data() as Map<String, dynamic>;
        final nama = data['nama'] ?? 'Tanpa Nama';
        final blok = data['blok'] ?? '';

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isAdminPage ? Colors.red[50] : const Color(0xFFE0E7FF),
            child: Icon(
              Icons.location_on_outlined,
              size: 16,
              color: isAdminPage ? Colors.red : const Color(0xFF1E3A8A),
            ),
          ),
          title: Text(
            nama,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: blok.toString().isNotEmpty
              ? Text("Blok $blok", style: const TextStyle(fontSize: 11))
              : null,
          onTap: () {
            _searchController.clear();
            setState(() {
              _searchQuery = "";
            });
            FocusScope.of(context).unfocus();

            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              LatLng targetLatLng = LatLng(geo.latitude, geo.longitude);

              context.read<MapProvider>().moveCamera(targetLatLng, zoom: 19.0);
              _showAdminWargaInfo(context, doc.id, data);
            }
          },
        );
      },
    );
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_activeFilter == filter) {
        _activeFilter = null;
      } else {
        _activeFilter = filter;
      }
    });
  }

  String _getFilterName(String filter) {
    switch (filter) {
      case 'total':
        return 'Total Warga';
      case 'penerima':
        return 'Penerima';
      case 'sudah_cair':
        return 'Sudah Cair';
      case 'belum_cair':
        return 'Belum Cair';
      case 'terpetakan':
        return 'Terpetakan';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDocId = widget.highlightDocId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.centerOnLocation != null) {
        context.read<MapProvider>().moveCamera(widget.centerOnLocation!, zoom: 19.0);
      }
    });
  }

  // --- FUNGSI BUKA GOOGLE MAPS EKSTERNAL ---
  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal membuka Maps")));
      }
    }
  }

  // --- WIDGET DASHBOARD RINGKAS ---
  Widget _buildDashboardCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('warga').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final totalWarga = docs.length;

        final penerimaBansos = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['menerima_bantuan'] == 'Ya';
        }).length;

        final sudahCair = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status_cair'] == 'Sudah Menerima';
        }).length;

        final belumCair = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['menerima_bantuan'] == 'Ya' &&
              data['status_cair'] != 'Sudah Menerima';
        }).length;

        final terpetakan = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['lokasi'] != null;
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDashboardExpanded = !_isDashboardExpanded;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDashboardExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: const Color(0xFF1E3A8A),
                      size: 24,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Ringkasan Data",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (_activeFilter != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeFilter = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Filter: ${_getFilterName(_activeFilter!)}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.close,
                                size: 10,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (!_isDashboardExpanded) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$totalWarga Warga",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isDashboardExpanded
                  ? Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  Icons.people,
                                  "Total Warga",
                                  totalWarga.toString(),
                                  Colors.blue,
                                  isActive: _activeFilter == 'total',
                                  onTap: () => _toggleFilter('total'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  Icons.volunteer_activism,
                                  "Penerima",
                                  penerimaBansos.toString(),
                                  Colors.orange,
                                  isActive: _activeFilter == 'penerima',
                                  onTap: () => _toggleFilter('penerima'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  Icons.check_circle,
                                  "Sudah Cair",
                                  sudahCair.toString(),
                                  Colors.green,
                                  isActive: _activeFilter == 'sudah_cair',
                                  onTap: () => _toggleFilter('sudah_cair'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  Icons.hourglass_bottom,
                                  "Belum Cair",
                                  belumCair.toString(),
                                  Colors.red,
                                  isActive: _activeFilter == 'belum_cair',
                                  onTap: () => _toggleFilter('belum_cair'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _statCard(
                            Icons.location_on,
                            "Rumah Terpetakan",
                            "$terpetakan / $totalWarga",
                            Colors.purple,
                            isHorizontal: true,
                            isActive: _activeFilter == 'terpetakan',
                            onTap: () => _toggleFilter('terpetakan'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    bool isHorizontal = false,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.18) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.2),
            width: isActive ? 2.2 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: isHorizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('warga').snapshots(),
        builder: (context, snapshot) {
          Set<Marker> markers = {};
          LatLng? selectedLatLng;
          List<DocumentSnapshot> allWargaDocs = [];
          if (snapshot.hasData) {
            allWargaDocs = snapshot.data!.docs;
            for (var doc in allWargaDocs) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['lokasi'] != null) {
                // Terapkan Filter Peta Aktif dari Dashboard
                if (_activeFilter != null) {
                  bool matches = false;
                  if (_activeFilter == 'total') {
                    matches = true;
                  } else if (_activeFilter == 'penerima') {
                    matches = (data['menerima_bantuan'] == 'Ya');
                  } else if (_activeFilter == 'sudah_cair') {
                    matches = (data['status_cair'] == 'Sudah Menerima');
                  } else if (_activeFilter == 'belum_cair') {
                    matches = (data['menerima_bantuan'] == 'Ya' &&
                        data['status_cair'] != 'Sudah Menerima');
                  } else if (_activeFilter == 'terpetakan') {
                    matches = true; // Karena sudah difilter data['lokasi'] != null
                  }
                  if (!matches) continue;
                }

                GeoPoint geoPoint = data['lokasi'];
                bool isSelected = (_selectedDocId == doc.id);
                if (isSelected) {
                  selectedLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
                }

                // Logika pewarnaan marker tematik sesuai proposal
                double markerHue = BitmapDescriptor.hueBlue; // Default: Tidak menerima bantuan
                if (data['menerima_bantuan'] == 'Ya') {
                  if (data['status_cair'] == 'Sudah Menerima') {
                    markerHue = BitmapDescriptor.hueGreen;
                  } else {
                    markerHue = BitmapDescriptor.hueRed;
                  }
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    icon: isSelected
                        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet)
                        : BitmapDescriptor.defaultMarkerWithHue(markerHue),
                    onTap: () => _showAdminWargaInfo(context, doc.id, data),
                  ),
                );
              }
            }
          }

          Set<Circle> circles = {};
          if (selectedLatLng != null) {
            circles.add(
              Circle(
                circleId: const CircleId('selected_home_highlight'),
                center: selectedLatLng,
                radius: 20.0, // 20 meter radius
                fillColor: const Color(0xFF1E3A8A).withOpacity(0.18),
                strokeColor: const Color(0xFF1E3A8A),
                strokeWidth: 2,
              ),
            );
          }

          return Stack(
            children: [
              GoogleMap(
                mapType: mapProvider.currentMapType,
                initialCameraPosition: CameraPosition(
                  target: widget.centerOnLocation ?? const LatLng(-6.850071, 107.930230),
                  zoom: 18.0,
                ),
                onMapCreated: (controller) {
                  context.read<MapProvider>().setController(controller);
                },
                onTap: (point) {
                  FocusScope.of(context).unfocus();
                  if (_selectedDocId != null) setState(() => _selectedDocId = null);
                },
                markers: markers,
                circles: circles,
                polylines: mapProvider.polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: const EdgeInsets.only(bottom: 25, left: 10),
              ),

              // Header Admin (Search & Logout) & Dashboard
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: "Cari Data Warga",
                                      filled: false,
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(
                                          left: 15,
                                          right: 10,
                                        ),
                                        child: Icon(Icons.search, color: Colors.grey),
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = "";
                                                });
                                              },
                                              child: const Icon(
                                                Icons.clear,
                                                color: Colors.grey,
                                              ),
                                            )
                                          : null,
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 15,
                                      ),
                                      border: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(30),
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(30),
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(30),
                                        ),
                                        borderSide: BorderSide(
                                          color: Color(0xFF1E3A8A),
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.search,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    onSubmitted: (value) {
                                      FocusScope.of(context).unfocus();
                                      if (value.trim().isNotEmpty) {
                                        _searchController.clear();
                                        final currentQuery = _searchQuery;
                                        setState(() {
                                          _searchQuery = "";
                                        });
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SearchResultsPage(
                                              query: currentQuery,
                                              isAdmin: true,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),

                                // Suggestions Overlay
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        )
                                      ],
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    constraints: const BoxConstraints(maxHeight: 250),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: _buildSuggestionsList(context, allWargaDocs, true),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Material(
                              elevation: 5,
                              shape: const CircleBorder(),
                              color: Colors.red,
                              child: CircleAvatar(
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                  ),
                                  tooltip: "Logout Admin",
                                  onPressed: () async {
                                    await authProvider.signOut();

                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const LoginPage(),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_searchQuery.isEmpty) _buildDashboardCards(),
                    ],
                  ),
                ),
              ),

              // Tombol Hapus Rute
              if (mapProvider.polylines.isNotEmpty)
                Positioned(
                  bottom: 90, // Lebih tinggi agar tidak menumpuk dengan FAB Tambah Data
                  right: 15,
                  child: FloatingActionButton.extended(
                    onPressed: () => mapProvider.clearRoute(),
                    backgroundColor: Colors.red[800],
                    icon: const Icon(Icons.clear, color: Colors.white),
                    label: const Text("Hapus Rute", style: TextStyle(color: Colors.white)),
                  ),
                ),

              // Indikator Loading Rute
              if (mapProvider.isLoadingRoute)
                const Center(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("Memuat Rute..."),
                        ],
                      ),
                    ),
                  ),
                ),

              // Tombol Ganti Tipe Peta (Map Type Switcher)
              Positioned(
                bottom: mapProvider.polylines.isNotEmpty ? 150 : 90,
                right: 15,
                child: FloatingActionButton(
                  heroTag: "btnMapTypeAdmin",
                  mini: true,
                  onPressed: () => mapProvider.toggleMapType(),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  tooltip: "Ganti Tipe Peta",
                  child: const Icon(Icons.layers_outlined),
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2C3E50),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah Data", style: TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormWargaPage())),
      ),
    );
  }

  void _showAdminWargaInfo(BuildContext context, String docId, Map<String, dynamic> data) {
    setState(() => _selectedDocId = docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return WargaInfoSheet(
          docId: docId,
          data: data,
          isAdmin: true,
          onRoutePressed: () async {
            Navigator.pop(context); // Tutup bottom sheet
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              final mapProv = context.read<MapProvider>();
              final success = await mapProv.drawRoute(geo.latitude, geo.longitude);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(mapProv.errorMessage ?? "Gagal memuat rute")),
                );
              }
            }
          },
          onExternalMapPressed: () {
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              _openExternalMap(geo.latitude, geo.longitude);
            }
          },
          onEditPressed: () {
            Navigator.pop(context); // Tutup bottom sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FormWargaPage(
                  docId: docId,
                  existingData: data,
                ),
              ),
            );
          },
          onDeletePressed: () {
            _konfirmasiHapus(context, docId, data['nama']);
          },
        );
      },
    ).whenComplete(() {
      setState(() => _selectedDocId = null);
    });
  }

  void _konfirmasiHapus(BuildContext context, String docId, String? nama) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: Text("Yakin ingin menghapus data '$nama' secara permanen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx); // Tutup dialog konfirmasi
              Navigator.pop(context); // Tutup bottom sheet info
              
              final wargaProvider = context.read<WargaProvider>();
              final success = await wargaProvider.deleteWarga(docId);
              
              if (mounted) {
                if (success) {
                  setState(() => _selectedDocId = null);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Terhapus")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(wargaProvider.errorMessage ?? "Gagal menghapus")),
                  );
                }
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
