import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  String? _errorMessage;
  MapType _currentMapType = MapType.normal;


  GoogleMapController? get mapController => _mapController;
  Set<Polyline> get polylines => _polylines;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get errorMessage => _errorMessage;
  MapType get currentMapType => _currentMapType;

  void setController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void toggleMapType() {
    _currentMapType = (_currentMapType == MapType.normal) ? MapType.hybrid : MapType.normal;
    _mapController?.setMapStyle(null);
    notifyListeners();
  }

  // --- Fungsi yang hilang ---

  void moveCamera(LatLng target, {double zoom = 18.0}) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void clearRoute() {
    _polylines = {};
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> drawRoute(double destLat, double destLng) async {
    _isLoadingRoute = true;
    _errorMessage = null;
    notifyListeners();
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Layanan lokasi (GPS) dinonaktifkan. Silakan aktifkan GPS pada HP Anda.';
        _isLoadingRoute = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Izin akses lokasi ditolak.';
          _isLoadingRoute = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk memberikan izin.';
        _isLoadingRoute = false;
        notifyListeners();
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      LatLng start = LatLng(position.latitude, position.longitude);
      LatLng end = LatLng(destLat, destLng);
      List<LatLng> routePoints = await RoutingService.getRoute(start, end);
      
      if (routePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route_path'),
            points: routePoints,
            color: Colors.blue,
            width: 6,
          ),
        };
        _isLoadingRoute = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoadingRoute = false;
    notifyListeners();
    return false;
  }
}