import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
        title: const Text("Geser Peta ke Titik Rumah"),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text("Koordinat Terpilih:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    "${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50)),
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
