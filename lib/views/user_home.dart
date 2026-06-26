import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'search_results.dart';
import '../providers/map_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart'; // Import ThemeProvider
import '../widgets/warga_info_sheet.dart';
import '../utils/date_formatter.dart';

class UserHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;

  const UserHomePage({super.key, this.centerOnLocation, this.highlightDocId});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? _selectedDocId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool? _wasLoggedIn;
  String _searchQuery = "";

  BitmapDescriptor? _blueDotIcon;
  BitmapDescriptor? _redDotIcon;

  @override
  void initState() {
    super.initState();
    _selectedDocId = widget.highlightDocId;
    _initMarkerIcons();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.centerOnLocation != null) {
        context.read<MapProvider>().moveCamera(widget.centerOnLocation!, zoom: 19.0);
      }
    });
  }

  Future<void> _initMarkerIcons() async {
    _blueDotIcon = await _createDotIcon(const Color(0xFF1E3A8A), 18);
    _redDotIcon = await _createDotIcon(Colors.red, 22);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createDotIcon(Color color, double radius) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final Paint paint = Paint()..color = color;
    final Paint strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawCircle(Offset(radius + 4, radius + 5), radius, shadowPaint);
    canvas.drawCircle(Offset(radius + 4, radius + 4), radius, paint);
    canvas.drawCircle(Offset(radius + 4, radius + 4), radius, strokePaint);

    final int size = (radius * 2 + 8).toInt();
    final ui.Image image = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    if (_wasLoggedIn != null && _wasLoggedIn != isLoggedIn) {
      _searchController.clear();
    }
    _wasLoggedIn = isLoggedIn;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSuggestionsList(BuildContext context, List<DocumentSnapshot> docs, bool isAdminPage, bool isDark) {
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
      return ListTile(
        leading: const Icon(Icons.search_off, color: Colors.grey),
        title: const Text("Tidak ada hasil cocok", style: TextStyle(color: Colors.grey)),
      );
    }

    final displayList = suggestions.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayList.length + (suggestions.length > 5 ? 1 : 0),
      separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2)),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return ListTile(
            dense: true,
            tileColor: isDark ? const Color(0xFF0F172A) : Colors.blue.withOpacity(0.05),
            title: Text(
              "Lihat semua hasil untuk '$_searchQuery'...",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF3B82F6)),
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
            backgroundColor: isAdminPage ? Colors.red.withOpacity(0.2) : const Color(0xFF3B82F6).withOpacity(0.2),
            child: Icon(
              Icons.location_on_outlined,
              size: 16,
              color: isAdminPage ? Colors.red : const Color(0xFF3B82F6),
            ),
          ),
          title: Text(
            nama,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: blok.toString().isNotEmpty
              ? Text("Blok $blok", style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54))
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
              _showWargaInfo(context, doc.id, data);
            }
          },
        );
      },
    );
  }

  // --- FUNGSI BUKA GOOGLE MAPS EKSTERNAL ---
  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");

    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak dapat membuka Google Maps")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedInWarga = authProvider.isLoggedIn && (authProvider.user?.email ?? '').endsWith('@warga.sigbansos.com');
    
    // DETEKSI TEMA
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapProvider = context.watch<MapProvider>();
    //final String activeMapId = '3a650f80a137987b730a3339';
    //debugPrint("Current Theme isDark: $isDark | Active Map ID: $activeMapId");
    /*final String darkStyle = '''
    [
      // 1. Tanah Dasar (Hitam Sangat Gelap)
      { "elementType": "geometry", "stylers": [{ "color": "#0d1117" }] },
      { "elementType": "labels.text.fill", "stylers": [{ "color": "#8b96a5" }] },
      { "elementType": "labels.text.stroke", "stylers": [{ "color": "#0d1117" }] },
      
      // 2. Blok Bangunan/Pemukiman (Dibuat TERANG agar sangat kontras)
      { "featureType": "landscape.man_made", "elementType": "geometry.fill", "stylers": [{ "color": "#304052" }] },
      // Tetap paksa stroke warna putih terang jaga-jaga jika ada data poligon bangunan
      { "featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{ "color": "#ffffff" }, { "weight": 2.0 }] },
      
      // 3. Dataran/Hutan (Hijau Gelap)
      { "featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [{ "color": "#121f16" }] },
      
      // 4. Jalan (Dibuat lebih biru agar beda dengan bangunan)
      { "featureType": "road", "elementType": "geometry.fill", "stylers": [{ "color": "#1e2b3c" }] },
      { "featureType": "road.local", "elementType": "geometry.fill", "stylers": [{ "color": "#4a6280" }] },
      { "featureType": "road", "elementType": "geometry.stroke", "stylers": [{ "visibility": "off" }] },
      
      // 5. Perairan (Biru Navy)
      { "featureType": "water", "elementType": "geometry.fill", "stylers": [{ "color": "#0a1d36" }] },
      { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{ "color": "#5a7a9e" }] },
      
      // 6. POI (Tetap nyala)
      { "featureType": "poi", "stylers": [{ "visibility": "on" }] },
      { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{ "color": "#d59563" }] }
    ]
    ''';*/
    
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
                GeoPoint geoPoint = data['lokasi'];
                bool isSelected = (_selectedDocId == doc.id);
                if (isSelected) {
                  selectedLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    icon: isSelected
                        ? (_redDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed))
                        : (_blueDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
                    onTap: () => _showWargaInfo(context, doc.id, data),
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
                radius: 20.0,
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
                onMapCreated: (GoogleMapController controller) {
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
                mapToolbarEnabled: true,
                padding: const EdgeInsets.only(bottom: 25, left: 10),
              ),

              // Search bar dan Login button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                                    ]
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: "Cari Warga",
                                      hintStyle: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey),
                                      filled: false,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(left: 15, right: 10),
                                        child: Icon(
                                          Icons.search,
                                          color: isDark ? Colors.white70 : Colors.grey[700],
                                        ),
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = "";
                                                });
                                              },
                                              child: Icon(
                                                Icons.clear,
                                                color: isDark ? Colors.white70 : Colors.grey[700],
                                              ),
                                            )
                                          : null,
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 15,
                                      ),
                                      border: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(30)),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(30)),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(30)),
                                        borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.8),
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
                                              isAdmin: false,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),

                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.98),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3), width: 1.5),
                                    ),
                                    constraints: const BoxConstraints(maxHeight: 250),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: _buildSuggestionsList(context, allWargaDocs, false, isDark),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),
                      const SizedBox(width: 10),

                      // --- TOMBOL GANTI TEMA ---
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Material(
                          elevation: 5,
                          shape: const CircleBorder(),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            child: IconButton(
                              icon: Icon(
                                isDark ? Icons.light_mode : Icons.dark_mode,
                                color: isDark ? Colors.amber : Colors.blue[800],
                              ),
                              tooltip: "Ganti Tema",
                              onPressed: () => context.read<ThemeProvider>().toggleTheme(!isDark),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8), // Jarak ke tombol Profil/Logout

                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Material(
                          elevation: 5,
                          shape: const CircleBorder(),
                          color: isDark ? const Color(0xFF1E293B) : Colors.blue[600],
                          child: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue[600],
                            child: isLoggedInWarga
                                ? IconButton(
                                    icon: const Icon(Icons.person, color: Colors.white),
                                    tooltip: "Profil Saya",
                                    onPressed: () => _showProfilWarga(context, authProvider.user!.email!),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.login, color: Colors.white),
                                    tooltip: "Login",
                                    onPressed: () => Navigator.pushNamed(context, '/login'),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol Hapus Rute
              if (mapProvider.polylines.isNotEmpty)
                Positioned(
                  bottom: 30,
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
                Center(
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 4,
                    child: const Padding(
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
                bottom: mapProvider.polylines.isNotEmpty ? 90 : 30,
                right: 15,
                child: FloatingActionButton(
                  heroTag: "btnMapTypeUser",
                  mini: true,
                  onPressed: () => mapProvider.toggleMapType(),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  tooltip: "Ganti Tipe Peta",
                  child: const Icon(Icons.layers_outlined),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWargaInfo(BuildContext context, String docId, Map<String, dynamic> data) {
    setState(() => _selectedDocId = docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return WargaInfoSheet(
          docId: docId,
          data: data,
          isAdmin: false,
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
        );
      },
    ).whenComplete(() {
      setState(() => _selectedDocId = null);
      _searchFocusNode.unfocus();
      FocusScope.of(context).unfocus();
    });
  }

  void _showProfilWarga(BuildContext context, String email) {
    final String nik = email.split('@')[0];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Stream<QuerySnapshot> profileStream = FirebaseFirestore.instance
        .collection('warga')
        .where('nik', isEqualTo: nik)
        .snapshots();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        "Profil Warga Tidak Ditemukan",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Akun NIK $nik belum terdaftar di sistem warga Ketua RT. Silakan hubungi Ketua RT.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await context.read<AuthProvider>().signOut();
                          },
                          child: const Text("Keluar Sesi / Logout"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final docId = snapshot.data!.docs.first.id;
            final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nama'] ?? 'Tanpa Nama',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Text("Akun Resmi Warga Tegalsari", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Divider(height: 24),
                      const Text(
                        "DATA KEPENDUDUKAN",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      _profilRow("Nama Kepala Keluarga", data['nama']),
                      _profilRow("NIK", data['nik']),
                      _profilRow("No. KK", data['no_kk']),
                      _profilRow("Blok/Gang", data['blok']),
                      const SizedBox(height: 24),

                      const Text(
                        "STATUS BANTUAN SOSIAL (BANSOS)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: data['menerima_bantuan'] == 'Ya'
                              ? Colors.green.withOpacity(isDark ? 0.1 : 0.05)
                              : Colors.grey.withOpacity(isDark ? 0.1 : 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: data['menerima_bantuan'] == 'Ya'
                                ? Colors.green.withOpacity(isDark ? 0.3 : 0.1)
                                : Colors.grey.withOpacity(isDark ? 0.3 : 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _profilRow("Penerima Bantuan?", data['menerima_bantuan']),
                            if (data['menerima_bantuan'] == 'Ya') ...[
                              const Divider(height: 16),
                              _profilRow("Jenis Bantuan", data['jenis_bantuan']),
                              _profilRow("Status Cair", data['status_cair']),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        "RIWAYAT PENYALURAN BANSOS",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      
                      if (data['menerima_bantuan'] == 'Ya')
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('warga')
                              .doc(docId)
                              .collection('riwayat_bansos')
                              .orderBy('tanggal_diterima', descending: true)
                              .snapshots(),
                          builder: (context, riwayatSnapshot) {
                            if (riwayatSnapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            if (!riwayatSnapshot.hasData || riwayatSnapshot.data!.docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  "Belum ada riwayat penerimaan bansos untuk akun ini.",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: riwayatSnapshot.data!.docs.length,
                              separatorBuilder: (context, index) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final riwayatData = riwayatSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                                final jenisBantuan = riwayatData['jenis_bantuan'] ?? '-';
                                final rawDate = riwayatData['tanggal_diterima'];
                                
                                String tanggalFormat = '-';
                                if (rawDate != null) {
                                  if (rawDate is Timestamp) {
                                    tanggalFormat = DateFormatter.formatIndonesianDate(rawDate.toDate());
                                  } else if (rawDate is String) {
                                    tanggalFormat = rawDate;
                                  }
                                }

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFDCFCE7),
                                    child: const Icon(Icons.check_circle, color: Colors.green),
                                  ),
                                  title: Text(
                                    "Bantuan $jenisBantuan",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "Diterima pada: $tanggalFormat",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.green[400] : Colors.green[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Tidak ada riwayat bantuan sosial untuk akun NIK ini.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                _showUbahPasswordDialog(context);
                              },
                              icon: const Icon(Icons.lock_reset),
                              label: const Text("Ubah Password"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.red[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await context.read<AuthProvider>().signOut();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Berhasil keluar dari akun warga")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text("Keluar Sesi"),
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
      },
    );
  }

  Widget _profilRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showUbahPasswordDialog(BuildContext parentContext) {
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        String? dialogErrorMessage;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text("Ubah Password", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogErrorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[800], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogErrorMessage!,
                                  style: TextStyle(color: Colors.red[900], fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        "Masukkan password baru Anda. Password minimal terdiri dari 6 karakter.",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: "Password Baru",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Password baru tidak boleh kosong";
                          }
                          if (value.length < 6) {
                            return "Password minimal 6 karakter";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Konfirmasi Password Baru",
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return "Password konfirmasi tidak sama";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isLoading = true;
                              dialogErrorMessage = null;
                            });
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await user.updatePassword(newPasswordController.text);
                                if (parentContext.mounted) {
                                  final messenger = ScaffoldMessenger.of(parentContext);
                                  Navigator.pop(dialogContext); // Tutup dialog Ubah Password
                                  Navigator.pop(parentContext); // Tutup bottom sheet Profil
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("Password berhasil diperbarui!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                throw FirebaseAuthException(
                                  code: 'no-user',
                                  message: 'Pengguna tidak terdeteksi aktif.',
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              String errMsg = "Gagal memperbarui password: ${e.message}";
                              if (e.code == 'requires-recent-login') {
                                errMsg = "Sesi Anda sudah kedaluwarsa demi keamanan. Silakan keluar (logout) dan login kembali sebelum mengubah password.";
                              }
                              setState(() {
                                dialogErrorMessage = errMsg;
                              });
                            } catch (e) {
                              setState(() {
                                dialogErrorMessage = "Terjadi kesalahan: $e";
                              });
                            } finally {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}