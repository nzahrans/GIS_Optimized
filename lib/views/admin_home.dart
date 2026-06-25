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

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // StreamBuilder untuk membaca Pin Marker secara realtime dari Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('warga').snapshots(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['lokasi'] != null) {
                    GeoPoint geoPoint = data['lokasi'];
                    bool isSelected = (_selectedDocId == doc.id);

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
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.centerOnLocation ?? const LatLng(-6.850071, 107.930230),
                  zoom: 18.0,
                ),
                onMapCreated: (controller) {
                  context.read<MapProvider>().setController(controller);
                },
                onTap: (point) {
                  if (_selectedDocId != null) setState(() => _selectedDocId = null);
                },
                markers: markers,
                polylines: mapProvider.polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),

          // Header Admin (Search & Logout)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      elevation: 5, shape: const CircleBorder(), color: Colors.red,
                      child: CircleAvatar(
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: "Logout Admin",
                          onPressed: () async {
                            await authProvider.signOut();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Cari Data Warga",
                        filled: false,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 15, right: 10),
                          child: Icon(Icons.search),
                        ),
                        contentPadding: EdgeInsets.only(top: 14, bottom: 14, right: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide(
                            color: Color(0xFF1E3A8A),
                            width: 1.8,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SearchResultsPage(query: value, isAdmin: true)));
                        }
                      },
                    ),
                  ),
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
        ],
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
