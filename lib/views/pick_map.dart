import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/map_provider.dart';

class PickMapPage extends StatefulWidget {
  final LatLng? initialCenter; // Lokasi awal jika ada
  final String? docId; // ID warga yang sedang diedit agar markernya disembunyikan

  const PickMapPage({
    super.key,
    this.initialCenter,
    this.docId,
  });

  @override
  State<PickMapPage> createState() => _PickMapPageState();
}

class _PickMapPageState extends State<PickMapPage> {
  // Koordinat tengah peta saat ini (Default: Tegalsari)
  LatLng _currentCenter = const LatLng(-6.849041, 107.929190);

  BitmapDescriptor? _blueDotIcon;
  BitmapDescriptor? _greenDotIcon;
  BitmapDescriptor? _redDotIcon;
  double? _lastDevicePixelRatio;

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _currentCenter = widget.initialCenter!;
    }
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
    _blueDotIcon = await _createDotIcon(const Color(0xFF1E3A8A), 12, dpr);
    _greenDotIcon = await _createDotIcon(Colors.green, 12, dpr);
    _redDotIcon = await _createDotIcon(Colors.red, 12, dpr);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createDotIcon(Color color, double radius, double dpr) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Efek Shadow/Glow (Hitam Transparan)
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
  Widget build(BuildContext context) {
    // Deteksi Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Lokasi Rumah"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Kirim koordinat kembali ke Halaman Form
              Navigator.pop(context, _currentCenter);
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('warga').snapshots(),
        builder: (context, snapshot) {
          Set<Marker> markers = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              // Jika ini warga yang sedang kita edit lokasinya, sembunyikan marker lamanya
              if (widget.docId != null && doc.id == widget.docId) {
                continue;
              }

              var data = doc.data() as Map<String, dynamic>;
              if (data['lokasi'] != null) {
                GeoPoint geoPoint = data['lokasi'];

                BitmapDescriptor? markerIcon;
                if (data['menerima_bantuan'] == 'Ya') {
                  if (data['status_cair'] == 'Sudah Menerima') {
                    markerIcon = _greenDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
                  } else {
                    markerIcon = _redDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
                  }
                } else {
                  markerIcon = _blueDotIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    icon: markerIcon,
                    infoWindow: InfoWindow(
                      title: data['nama'] ?? 'Tanpa Nama',
                      snippet: 'Blok ${data['blok'] ?? '-'}',
                    ),
                  ),
                );
              }
            }
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentCenter,
                  zoom: 19.0, // Zoom sangat dekat
                ),
                onMapCreated: (controller) {
                  context.read<MapProvider>().setController(controller);
                },
                onCameraMove: (position) {
                  // Update koordinat setiap peta digeser
                  setState(() {
                    _currentCenter = position.target;
                  });
                },
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),

              // PIN DI TENGAH LAYAR (Target)
              // Digeser ke atas sebesar 25 pixel (setengah tinggi icon) agar ujung bawah pin menunjuk tepat pada titik tengah peta
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -25),
                  child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                ),
              ),

              // Tampilan Koordinat Real-time di Bawah
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.26 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Koordinat Terpilih:",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                      Text(
                        "${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                          onPressed: () {
                            Navigator.pop(context, _currentCenter);
                          },
                          child: const Text("Pilih Lokasi Ini", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}