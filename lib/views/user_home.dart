import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'search_results.dart';
import '../providers/map_provider.dart';
import '../widgets/warga_info_sheet.dart';

class UserHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;

  const UserHomePage({super.key, this.centerOnLocation, this.highlightDocId});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
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
            const SnackBar(content: Text("Tidak dapat membuka Google Maps")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();

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

                    markers.add(
                      Marker(
                        markerId: MarkerId(doc.id),
                        position: LatLng(geoPoint.latitude, geoPoint.longitude),
                        icon: isSelected
                            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        onTap: () => _showWargaInfo(context, doc.id, data),
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

          // Search bar dan Login button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      elevation: 5, shape: const CircleBorder(), color: Colors.white,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.login, color: Colors.blue),
                          tooltip: "Login Admin",
                          onPressed: () => Navigator.pushNamed(context, '/login'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Cari Lokasi Rumah Warga...",
                        border: InputBorder.none,
                        filled: false,
                        icon: Icon(Icons.search, color: Colors.grey),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SearchResultsPage(query: value, isAdmin: false)));
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
    );
  }

  void _showWargaInfo(BuildContext context, String docId, Map<String, dynamic> data) {
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
    });
  }
}
