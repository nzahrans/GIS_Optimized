import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'form_warga.dart';
import 'search_results.dart';
import 'user_home.dart';
import '../providers/auth_provider.dart';
import '../providers/map_provider.dart';
import '../providers/warga_provider.dart';
import '../providers/theme_provider.dart'; // Import ThemeProvider
import '../widgets/warga_info_sheet.dart';
import '../widgets/anggota_info_sheet.dart';
import '../widgets/custom_alert_dialog.dart';
import '../models/anggota_keluarga.dart';
import '../services/firestore_service.dart';
import 'form_anggota.dart';

class AdminHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;
  final String? highlightAnggotaId;

  const AdminHomePage({
    super.key,
    this.centerOnLocation,
    this.highlightDocId,
    this.highlightAnggotaId,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String? _selectedDocId;
  PersistentBottomSheetController? _activeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDashboardExpanded = true;
  String? _activeFilter;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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
        context.read<MapProvider>().moveCamera(
          widget.centerOnLocation!,
          zoom: 19.0,
        );
      }
      if (widget.highlightDocId != null) {
        if (widget.highlightAnggotaId != null) {
          _fetchAndShowAdminAnggotaInfo(widget.highlightDocId!, widget.highlightAnggotaId!);
        } else {
          _fetchAndShowAdminWargaInfo(widget.highlightDocId!);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (_lastDevicePixelRatio != dpr) {
      _lastDevicePixelRatio = dpr;
      _initMarkerIcons(dpr);
    }
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
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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
      return const ListTile(
        leading: Icon(Icons.search_off, color: Colors.grey),
        title: Text(
          "Tidak ada hasil cocok",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final displayList = combinedSuggestions.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: displayList.length + (combinedSuggestions.length > 5 ? 1 : 0),
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2)),
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
            trailing: const Icon(
              Icons.arrow_forward,
              size: 16,
              color: Color(0xFF3B82F6),
            ),
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
                  builder: (context) =>
                      SearchResultsPage(query: searchVal, isAdmin: isAdminPage),
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
                : (isAdminPage
                    ? Colors.red.withOpacity(0.2)
                    : const Color(0xFF3B82F6).withOpacity(0.2)),
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
                _showAdminAnggotaInfo(
                  context,
                  suggestion['id'],
                  suggestion['data'],
                  suggestion['parentDocId'],
                  suggestion['parentData'],
                );
              } else {
                _showAdminWargaInfo(context, suggestion['id'], suggestion['data']);
              }
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

  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal membuka Maps")));
      }
    }
  }

  Widget _buildDashboardCards(bool isDark, List<DocumentSnapshot> wargaDocs, List<DocumentSnapshot> anggotaDocs) {
    final totalKK = wargaDocs.length;
    final totalAnggota = anggotaDocs.length;
    final totalPenduduk = totalKK + totalAnggota;

    final penerimaBansos = wargaDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['menerima_bantuan'] == 'Ya';
    }).length;

    final sudahCair = wargaDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status_cair'] == 'Sudah Menerima';
    }).length;

    final belumCair = wargaDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['menerima_bantuan'] == 'Ya' &&
          data['status_cair'] != 'Sudah Menerima';
    }).length;

    final terpetakan = wargaDocs.where((doc) {
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
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDashboardExpanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  color: isDark ? Colors.white70 : Colors.black87,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  "Ringkasan Data",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$totalKK KK / $totalPenduduk Jiwa",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
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
                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              Icons.home,
                              "Total KK",
                              totalKK.toString(),
                              const Color(0xFF60A5FA),
                              isActive: _activeFilter == 'total',
                              isDark: isDark,
                              onTap: () => _toggleFilter('total'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statCard(
                              Icons.groups,
                              "Total Penduduk",
                              totalPenduduk.toString(),
                              const Color(0xFF38BDF8),
                              isActive: false,
                              isDark: isDark,
                              onTap: () {}, // Hanya tampilan
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              Icons.volunteer_activism,
                              "Penerima",
                              penerimaBansos.toString(),
                              const Color(0xFFFB923C),
                              isActive: _activeFilter == 'penerima',
                              isDark: isDark,
                              onTap: () => _toggleFilter('penerima'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statCard(
                              Icons.check_circle,
                              "Sudah Cair",
                              sudahCair.toString(),
                              const Color(0xFF4ADE80),
                              isActive: _activeFilter == 'sudah_cair',
                              isDark: isDark,
                              onTap: () => _toggleFilter('sudah_cair'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              Icons.hourglass_bottom,
                              "Belum Cair",
                              belumCair.toString(),
                              const Color(0xFFF87171),
                              isActive: _activeFilter == 'belum_cair',
                              isDark: isDark,
                              onTap: () => _toggleFilter('belum_cair'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statCard(
                              Icons.location_on,
                              "KK Terpetakan",
                              "$terpetakan / $totalKK",
                              const Color(0xFFC084FC),
                              isActive: _activeFilter == 'terpetakan',
                              isDark: isDark,
                              onTap: () => _toggleFilter('terpetakan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _statCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    bool isHorizontal = false,
    bool isActive = false,
    required bool isDark,
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
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: isHorizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white.withOpacity(0.7) : Colors.black54),
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
                  Icon(icon, color: color, size: 24),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white.withOpacity(0.7) : Colors.black54),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definisi variabel isDark di sini
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapProvider = context.watch<MapProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    // Gunakan ID dari Dashboard Cloud Anda
    final String activeMapId = '3a650f80a137987b730a3339';

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
                    matches =
                        (data['menerima_bantuan'] == 'Ya' &&
                        data['status_cair'] != 'Sudah Menerima');
                  } else if (_activeFilter == 'terpetakan') {
                    matches = true; 
                  }
                  if (!matches) continue;
                }

                GeoPoint geoPoint = data['lokasi'];
                bool isSelected = (_selectedDocId == doc.id);
                if (isSelected) {
                  selectedLatLng = LatLng(
                    geoPoint.latitude,
                    geoPoint.longitude,
                  );
                }

                BitmapDescriptor? markerIcon;
                if (isSelected) {
                  markerIcon = _purpleDotIcon;
                } else if (data['menerima_bantuan'] == 'Ya') {
                  final String status = data['status_cair'] ?? 'Belum Menerima';
                  if (status == 'Dikonfirmasi Warga') {
                    markerIcon = _greenDotIcon;
                  } else if (status == 'Sudah Menerima') {
                    markerIcon = _amberDotIcon;
                  } else {
                    markerIcon = _redDotIcon;
                  }
                } else {
                  markerIcon = _blueDotIcon;
                }

                if (markerIcon == null) {
                  double markerHue = BitmapDescriptor.hueBlue;
                  if (isSelected) {
                    markerHue = BitmapDescriptor.hueViolet;
                  } else if (data['menerima_bantuan'] == 'Ya') {
                    final String status = data['status_cair'] ?? 'Belum Menerima';
                    if (status == 'Dikonfirmasi Warga') {
                      markerHue = BitmapDescriptor.hueGreen;
                    } else if (status == 'Sudah Menerima') {
                      markerHue = BitmapDescriptor.hueOrange;
                    } else {
                      markerHue = BitmapDescriptor.hueRed;
                    }
                  }
                  markerIcon = BitmapDescriptor.defaultMarkerWithHue(markerHue);
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    icon: markerIcon,
                    onTap: () => _showAdminWargaInfo(context, doc.id, data),
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
                mapId: activeMapId,
                mapType: mapProvider.currentMapType,
                initialCameraPosition: CameraPosition(
                  target:
                      widget.centerOnLocation ??
                      const LatLng(-6.849041, 107.929190),
                  zoom: 18.0,
                ),
                onMapCreated: (controller) {
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

              // Header Admin (Search & Logout) & Dashboard
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
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
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "Cari Data Warga",
                                          hintStyle: TextStyle(
                                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey,
                                          ),
                                          filled: false,
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 15,
                                              right: 10,
                                            ),
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
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 14,
                                                horizontal: 15,
                                              ),
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(30),
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder:
                                              const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(30),
                                                ),
                                                borderSide: BorderSide.none,
                                              ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(30),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Color(0xFF3B82F6),
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
                                                builder: (context) =>
                                                    SearchResultsPage(
                                                      query: currentQuery,
                                                      isAdmin: true,
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
                                      filter: ui.ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.98),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3), width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(
                                          maxHeight: 250,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: _buildSuggestionsList(
                                            context,
                                            allWargaDocs,
                                            allAnggotaDocs,
                                            true,
                                            isDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

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

                      // --- TOMBOL KEMBALI KE DASHBOARD ---
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Material(
                              elevation: 5,
                              shape: const CircleBorder(),
                              color: const Color(0xFF3B82F6),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFF3B82F6),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.dashboard,
                                    color: Colors.white,
                                  ),
                                  tooltip: "Kembali ke Dashboard",
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/admin_dashboard');
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),


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

              // === POSITIONED GABUNGAN TOMBOL PETA & RUTE ===
              Positioned(
                bottom: 75, // Cukup tinggi agar tidak menabrak tombol 'Tambah Data'
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end, // Agar rata kanan
                  children: [
                    // 1. Tombol Hapus Rute (Hanya muncul jika ada rute)
                    if (mapProvider.polylines.isNotEmpty) ...[
                      FloatingActionButton.extended(
                        heroTag: "btnHapusRuteAdmin",
                        onPressed: () => mapProvider.clearRoute(),
                        backgroundColor: Colors.red[800],
                        icon: const Icon(Icons.clear, color: Colors.white),
                        label: const Text(
                          "Hapus Rute",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12), // Jarak ke deretan tombol di bawahnya
                    ],

                    // 2. Barisan Tombol Recenter & Ganti Tipe Peta
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol Kembali ke Tengah (Recenter)
                        FloatingActionButton(
                          heroTag: "btnRecenterMapAdmin", // Wajib beda heroTag
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

                        const SizedBox(width: 8),

                        // Tombol Ganti Tipe Maps
                        FloatingActionButton(
                          heroTag: "btnMapTypeAdmin", // Wajib beda heroTag
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
              // === AKHIR POSITIONED GABUNGAN ===
              
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
            ]
          );
            },
          );
        },
      ),

      floatingActionButton: _selectedDocId != null
          ? null
          : FloatingActionButton.extended(
              // Jika dark mode, pakai warna searchbox (1E293B). Jika terang, pakai biru bawaan (3B82F6)
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF3B82F6),
              
              // Ikon dan Teks dipaksa selalu putih
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Tambah Data",
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold
                ),
              ),
              
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FormWargaPage()),
              ),
            ),
    );
  }

  Future<void> _fetchAndShowAdminWargaInfo(String docId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('warga').doc(docId).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        _showAdminWargaInfo(context, docId, data);
      }
    } catch (e) {
      debugPrint("Error fetching warga info: $e");
    }
  }

  void _showAdminWargaInfo(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    setState(() => _selectedDocId = docId);

    PersistentBottomSheetController? controller;
    controller = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return WargaInfoSheet(
          docId: docId,
          data: data,
          isAdmin: true,
          onRoutePressed: () async {
            controller?.close(); 
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
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
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              _openExternalMap(geo.latitude, geo.longitude);
            }
          },
          onEditPressed: () {
            controller?.close(); 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FormWargaPage(docId: docId, existingData: data),
              ),
            );
          },
          onDeletePressed: () {
            _konfirmasiHapus(context, docId, data['nama']);
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
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _konfirmasiHapus(BuildContext context, String docId, String? nama) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text("Hapus Data?"),
        content: Text("Yakin ingin menghapus data '$nama' secara permanen?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx); 
              Navigator.pop(context); 

              final wargaProvider = context.read<WargaProvider>();
              final success = await wargaProvider.deleteWarga(docId);

              if (mounted) {
                if (success) {
                  setState(() => _selectedDocId = null);
                  showDialog(
                    context: context,
                    builder: (ctx) => const CustomSuccessDialog(
                      title: "Terhapus!",
                      message: "Data warga berhasil dihapus secara permanen.",
                      buttonText: "Tutup",
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        wargaProvider.errorMessage ?? "Gagal menghapus",
                      ),
                    ),
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

  void _showAdminAnggotaInfo(
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
          isAdmin: true,
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
            _showAdminWargaInfo(context, parentDocId, parentData);
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

  Future<void> _fetchAndShowAdminAnggotaInfo(String parentDocId, String anggotaId) async {
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
        _showAdminAnggotaInfo(context, anggotaId, anggotaData, parentDocId, parentData);
      }
    } catch (e) {
      debugPrint("Error fetching anggota info: $e");
    }
  }
}