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
import '../widgets/anggota_info_sheet.dart';
import '../models/anggota_keluarga.dart';
import '../services/firestore_service.dart';
import '../utils/date_formatter.dart';

class UserHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;
  final String? highlightAnggotaId;

  const UserHomePage({
    super.key,
    this.centerOnLocation,
    this.highlightDocId,
    this.highlightAnggotaId,
  });

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? _selectedDocId;
  PersistentBottomSheetController? _activeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool? _wasLoggedIn;
  String _searchQuery = "";

  BitmapDescriptor? _blueDotIcon;
  BitmapDescriptor? _greenDotIcon;
  BitmapDescriptor? _redDotIcon;
  BitmapDescriptor? _amberDotIcon;
  BitmapDescriptor? _purpleDotIcon;
  double? _lastDevicePixelRatio;

  @override
  void initState() {
    super.initState();
    _selectedDocId = widget.highlightDocId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapProvider>().loadRtBoundaries();
      if (widget.centerOnLocation != null) {
        context.read<MapProvider>().moveCamera(widget.centerOnLocation!, zoom: 19.0);
      }
      if (widget.highlightDocId != null) {
        if (widget.highlightAnggotaId != null) {
          _fetchAndShowAnggotaInfo(widget.highlightDocId!, widget.highlightAnggotaId!);
        } else {
          _fetchAndShowWargaInfo(widget.highlightDocId!);
        }
      }
    });
  }

  Future<void> _initMarkerIcons(double dpr) async {
    _blueDotIcon = await _createDotIcon(const Color(0xFF1E3A8A), 7, dpr);
    _greenDotIcon = await _createDotIcon(Colors.green, 7, dpr);
    _redDotIcon = await _createDotIcon(Colors.red, 7, dpr);
    _amberDotIcon = await _createDotIcon(Colors.amber, 7, dpr);
    _purpleDotIcon = await _createDotIcon(Colors.purple, 10, dpr);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createDotIcon(Color color, double logicalRadius, double dpr) async {
    final double radius = logicalRadius * dpr;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * dpr);

    final Paint paint = Paint()..color = color;
    final Paint strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * dpr;

    canvas.drawCircle(Offset(radius + 2.0 * dpr, radius + 3.0 * dpr), radius, shadowPaint);
    canvas.drawCircle(Offset(radius + 2.0 * dpr, radius + 2.0 * dpr), radius, paint);
    canvas.drawCircle(Offset(radius + 2.0 * dpr, radius + 2.0 * dpr), radius, strokePaint);

    final int size = (radius * 2 + 4.0 * dpr).toInt();
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

    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (_lastDevicePixelRatio != dpr) {
      _lastDevicePixelRatio = dpr;
      _initMarkerIcons(dpr);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _kembaliKeTengah() async {
      // Ambil controller peta dari provider
      // (Sesuaikan nama '.mapController' dengan variabel yang ada di MapProvider-mu)
      final controller = context.read<MapProvider>().mapController; 
      
      // Titik pusat awal (hardcode bawaan aplikasimu)
      const LatLng titikPusat = LatLng(-6.849041, 107.929190); 

      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: titikPusat,
              zoom: 18.0, // Pastikan zoom-nya sama dengan saat awal buka
            ),
          ),
        );
      }
    }

  Widget _buildSuggestionsList(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
    List<DocumentSnapshot> anggotaDocs,
    bool isAdminPage,
    bool isDark,
  ) {
    final query = _searchQuery.toLowerCase().trim();
    final List<Map<String, dynamic>> combinedSuggestions = [];

    // 1. Filter warga (KK)
    for (var doc in wargaDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final nama = (data['nama'] ?? '').toString().toLowerCase();
      final nik = (data['nik'] ?? '').toString().toLowerCase();
      final blok = (data['blok'] ?? '').toString().toLowerCase();

      if (nama.contains(query) || nik.contains(query) || blok.contains(query)) {
        combinedSuggestions.add({
          'isAnggota': false,
          'id': doc.id,
          'nama': data['nama'] ?? 'Tanpa Nama',
          'subtitle': (data['blok'] ?? '').toString().isNotEmpty ? 'Blok ${data['blok']}' : 'Kepala Keluarga',
          'data': data,
          'parentDocId': doc.id,
          'parentData': data,
          'lokasi': data['lokasi'],
        });
      }
    }

    // 2. Filter anggota keluarga
    for (var doc in anggotaDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final nama = (data['nama'] ?? '').toString().toLowerCase();
      final nik = (data['nik'] ?? '').toString().toLowerCase();

      if (nama.contains(query) || nik.contains(query)) {
        String parentKkName = 'Tidak diketahui';
        Map<String, dynamic>? parentKkData;
        final parentDocId = doc.reference.parent.parent?.id;
        
        if (parentDocId != null) {
          try {
            final parentDoc = wargaDocs.firstWhere((w) => w.id == parentDocId);
            parentKkData = parentDoc.data() as Map<String, dynamic>?;
            parentKkName = parentKkData?['nama'] ?? 'Tidak diketahui';
          } catch (_) {}
        }

        combinedSuggestions.add({
          'isAnggota': true,
          'id': doc.id,
          'nama': data['nama'] ?? 'Tanpa Nama',
          'subtitle': "${data['hubungan'] ?? 'Anggota'} • KK: $parentKkName",
          'data': data,
          'parentDocId': parentDocId ?? '',
          'parentData': parentKkData,
          'lokasi': parentKkData?['lokasi'],
        });
      }
    }

    if (combinedSuggestions.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.search_off, color: Colors.grey),
        title: const Text("Tidak ada hasil cocok", style: TextStyle(color: Colors.grey)),
      );
    }

    final displayList = combinedSuggestions.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayList.length + (combinedSuggestions.length > 5 ? 1 : 0),
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
              _searchFocusNode.unfocus();
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

        final suggestion = displayList[index];
        final isAnggota = suggestion['isAnggota'] as bool;
        final nama = suggestion['nama'] as String;
        final subtitle = suggestion['subtitle'] as String;
        final locations = suggestion['lokasi'];

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isAnggota
                ? (isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.1))
                : (isAdminPage ? Colors.red.withOpacity(0.2) : const Color(0xFF3B82F6).withOpacity(0.2)),
            child: Icon(
              isAnggota ? Icons.people_outline : Icons.location_on_outlined,
              size: 16,
              color: isAnggota
                  ? Colors.purple
                  : (isAdminPage ? Colors.red : const Color(0xFF3B82F6)),
            ),
          ),
          title: Text(
            nama,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
          onTap: () {
            _searchFocusNode.unfocus();
            _searchController.clear();
            setState(() {
              _searchQuery = "";
            });
            FocusScope.of(context).unfocus();

            if (locations != null) {
              GeoPoint geo = locations;
              LatLng targetLatLng = LatLng(geo.latitude, geo.longitude);

              context.read<MapProvider>().moveCamera(targetLatLng, zoom: 19.0);
              
              if (isAnggota) {
                _showAnggotaInfo(
                  context,
                  suggestion['id'],
                  suggestion['data'],
                  suggestion['parentDocId'],
                  suggestion['parentData'],
                );
              } else {
                _showWargaInfo(context, suggestion['id'], suggestion['data']);
              }
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
    final isLoggedInWarga = authProvider.isLoggedIn && authProvider.role == 'user';
    
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
      key: _scaffoldKey,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('warga').snapshots(),
        builder: (context, snapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getAllAnggotaStream(),
            builder: (context, anggotaSnapshot) {
              Set<Marker> markers = {};
              LatLng? selectedLatLng;
              List<DocumentSnapshot> allWargaDocs = [];
              List<DocumentSnapshot> allAnggotaDocs = [];
              if (snapshot.hasData) {
                allWargaDocs = snapshot.data!.docs;
              }
              if (anggotaSnapshot.hasData) {
                allAnggotaDocs = anggotaSnapshot.data!.docs;
              }
            for (var doc in allWargaDocs) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['lokasi'] != null) {
                GeoPoint geoPoint = data['lokasi'];
                bool isSelected = (_selectedDocId == doc.id);
                if (isSelected) {
                  selectedLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
                }

                BitmapDescriptor? markerIcon;
                if (isSelected) {
                  markerIcon = _purpleDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
                } else {
                  markerIcon = _blueDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    icon: markerIcon,
                    onTap: () => _showWargaInfo(context, doc.id, data),
                  ),
                );
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
                  target: widget.centerOnLocation ?? const LatLng(-6.849041, 107.929190),
                  zoom: 18.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  context.read<MapProvider>().setController(controller);
                },
                onTap: (point) {
                  FocusScope.of(context).unfocus();
                  if (_selectedDocId != null) {
                    Navigator.pop(context);
                  }
                },
                markers: markers,
                circles: circles,
                polylines: mapProvider.polylines,
                polygons: mapProvider.polygons,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: const EdgeInsets.only(bottom: 25, left: 10),
              ),
              // Search bar dan Login button
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
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
                                       child: _buildSuggestionsList(context, allWargaDocs, allAnggotaDocs, false, isDark),
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
                                    icon: const Icon(Icons.dashboard, color: Colors.white),
                                    tooltip: "Dashboard Saya",
                                    onPressed: () => Navigator.pushReplacementNamed(context, '/user_dashboard'),
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

              Positioned(
                bottom: 30,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (mapProvider.polylines.isNotEmpty) ...[
                      FloatingActionButton.extended(
                        heroTag: "btnHapusRuteUser",
                        onPressed: () => mapProvider.clearRoute(),
                        backgroundColor: Colors.red[800],
                        icon: const Icon(Icons.clear, color: Colors.white),
                        label: const Text("Hapus Rute", style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Tombol Kembali ke Tengah (Recenter)
                        FloatingActionButton(
                          heroTag: "btnRecenterMapUser",
                          mini: true, 
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: _kembaliKeTengah,
                          child: const Icon(Icons.home_outlined),
                        ),
                        
                        const SizedBox(width: 5), // Jarak antar tombol
                        
                        // 2. Tombol Ganti Tipe Maps
                        FloatingActionButton(
                          heroTag: "btnMapTypeUser",
                          mini: true,
                          onPressed: () => mapProvider.toggleMapType(),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          tooltip: "Ganti Tipe Peta",
                          child: const Icon(Icons.layers_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Info Wilayah RT yang dipilih
              if (mapProvider.selectedRtName != null)
                Positioned(
                  bottom: 145, 
                  left: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map,
                              color: isDark ? Colors.blue[300] : const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    mapProvider.selectedRtName!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mapProvider.selectedRtKeterangan ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                mapProvider.clearSelectedRt();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Future<void> _fetchAndShowWargaInfo(String docId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('warga').doc(docId).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        _showWargaInfo(context, docId, data);
      }
    } catch (e) {
      debugPrint("Error fetching warga info: $e");
    }
  }

  void _showWargaInfo(BuildContext context, String docId, Map<String, dynamic> data) {
    setState(() => _selectedDocId = docId);

    PersistentBottomSheetController? controller;
    controller = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return WargaInfoSheet(
          docId: docId,
          data: data,
          isAdmin: false,
          onRoutePressed: () async {
            controller?.close(); // Tutup bottom sheet
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );

    _activeController = controller;

    controller?.closed.then((_) {
      if (mounted && _activeController == controller) {
        setState(() {
          _selectedDocId = null;
          _activeController = null;
        });
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
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
                        "Masukkan password baru Anda.\nPassword minimal terdiri dari 6 karakter.",
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

  void _showAnggotaInfo(
    BuildContext context,
    String anggotaId,
    Map<String, dynamic> anggotaData,
    String parentDocId,
    Map<String, dynamic> parentData,
  ) {
    setState(() => _selectedDocId = parentDocId);

    final anggotaObj = AnggotaKeluarga(
      id: anggotaId,
      parentDocId: parentDocId,
      nik: anggotaData['nik'] ?? '',
      nama: anggotaData['nama'] ?? '',
      noKk: anggotaData['no_kk'] ?? '',
      jenisKelamin: anggotaData['jenis_kelamin'] ?? 'Pria',
      hubungan: anggotaData['hubungan'] ?? 'Lainnya',
    );

    PersistentBottomSheetController? controller;
    controller = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return AnggotaInfoSheet(
          anggota: anggotaObj,
          parentData: parentData,
          isAdmin: false,
          onRoutePressed: () async {
            controller?.close();
            if (parentData['lokasi'] != null) {
              GeoPoint geo = parentData['lokasi'];
              final mapProv = context.read<MapProvider>();
              final success = await mapProv.drawRoute(
                geo.latitude,
                geo.longitude,
              );
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mapProv.errorMessage ?? "Gagal memuat rute"),
                  ),
                );
              }
            }
          },
          onExternalMapPressed: () {
            if (parentData['lokasi'] != null) {
              GeoPoint geo = parentData['lokasi'];
              _openExternalMap(geo.latitude, geo.longitude);
            }
          },
          onViewParentPressed: () {
            controller?.close();
            _showWargaInfo(context, parentDocId, parentData);
          },
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );

    _activeController = controller;

    controller?.closed.then((_) {
      if (mounted && _activeController == controller) {
        setState(() {
          _selectedDocId = null;
          _activeController = null;
        });
        _searchFocusNode.unfocus();
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _fetchAndShowAnggotaInfo(String parentDocId, String anggotaId) async {
    try {
      DocumentSnapshot parentDoc = await FirebaseFirestore.instance.collection('warga').doc(parentDocId).get();
      DocumentSnapshot anggotaDoc = await FirebaseFirestore.instance
          .collection('warga')
          .doc(parentDocId)
          .collection('anggota_keluarga')
          .doc(anggotaId)
          .get();

      if (parentDoc.exists && anggotaDoc.exists && mounted) {
        var parentData = parentDoc.data() as Map<String, dynamic>;
        var anggotaData = anggotaDoc.data() as Map<String, dynamic>;
        _showAnggotaInfo(context, anggotaId, anggotaData, parentDocId, parentData);
      }
    } catch (e) {
      debugPrint("Error fetching anggota info: $e");
    }
  }
}