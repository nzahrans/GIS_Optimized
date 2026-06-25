import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  String? _errorMessage;

  GoogleMapController? get mapController => _mapController;
  Set<Polyline> get polylines => _polylines;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get errorMessage => _errorMessage;

  void setController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Bersihkan data rute
  void clearRoute() {
    _polylines = {};
    _errorMessage = null;
    notifyListeners();
  }

  /// Gambar rute jalan dari posisi saat ini ke koordinat tujuan
  Future<bool> drawRoute(double destLat, double destLng) async {
    _isLoadingRoute = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Cek & Minta Izin Lokasi
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoadingRoute = false;
        _errorMessage = "Layanan lokasi (GPS) tidak aktif";
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLoadingRoute = false;
          _errorMessage = "Izin lokasi ditolak";
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLoadingRoute = false;
        _errorMessage = "Izin lokasi ditolak secara permanen. Aktifkan di pengaturan.";
        notifyListeners();
        return false;
      }

      // 2. Ambil Lokasi Terkini
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      LatLng start = LatLng(position.latitude, position.longitude);
      LatLng end = LatLng(destLat, destLng);

      // 3. Ambil Rute OSRM
      List<LatLng> routePoints = await RoutingService.getRoute(start, end);

      if (routePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route_path'),
            points: routePoints,
            color: Colors.blue[800]!,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };

        // 4. Sesuaikan kamera peta
        LatLngBounds bounds = _boundsFromPoints(start, end);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));

        _isLoadingRoute = false;
        notifyListeners();
        return true;
      } else {
        _isLoadingRoute = false;
        _errorMessage = "Gagal memuat jalur rute";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoadingRoute = false;
      _errorMessage = "Error routing: $e";
      notifyListeners();
      return false;
    }
  }

  /// Animasikan kamera peta ke koordinat tertentu
  void moveCamera(LatLng target, {double zoom = 18.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  // Helper untuk menentukan batas kamera agar mencakup awal dan akhir rute
  LatLngBounds _boundsFromPoints(LatLng p1, LatLng p2) {
    double minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
