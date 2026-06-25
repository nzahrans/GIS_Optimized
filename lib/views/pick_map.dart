import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/map_style.dart';

class PickMapPage extends StatefulWidget {
  final LatLng? initialCenter; // Lokasi awal jika ada

  const PickMapPage({super.key, this.initialCenter});

  @override
  State<PickMapPage> createState() => _PickMapPageState();
}

class _PickMapPageState extends State<PickMapPage> {
  // Koordinat tengah peta saat ini (Default: Tegalsari)
  LatLng _currentCenter = const LatLng(-6.850071, 107.930230);

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _currentCenter = widget.initialCenter!;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 19.0, // Zoom sangat dekat
            ),
            onMapCreated: (controller) {
              controller.setMapStyle(MapStyle.darkStyle);
            },
            onCameraMove: (position) {
              // Update koordinat setiap peta digeser
              setState(() {
                _currentCenter = position.target;
              });
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // PIN DI TENGAH LAYAR (Target)
          const Center(
            child: Icon(Icons.location_on, color: Colors.red, size: 50),
          ),

          // Tampilan Koordinat Real-time di Bawah
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text("Koordinat Terpilih:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    "${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                      onPressed: () {
                        Navigator.pop(context, _currentCenter);
                      },
                      child: const Text("Pilih Lokasi Ini", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
