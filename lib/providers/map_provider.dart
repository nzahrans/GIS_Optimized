import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};
  bool _isLoadingRoute = false;
  String? _errorMessage;
  MapType _currentMapType = MapType.normal;


  GoogleMapController? get mapController => _mapController;
  Set<Polyline> get polylines => _polylines;
  Set<Polygon> get polygons => _polygons;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get errorMessage => _errorMessage;
  MapType get currentMapType => _currentMapType;

  String? _selectedRtName;
  String? _selectedRtKeterangan;

  String? get selectedRtName => _selectedRtName;
  String? get selectedRtKeterangan => _selectedRtKeterangan;

  void selectRt(String? name, String? keterangan) {
    _selectedRtName = name;
    _selectedRtKeterangan = keterangan;
    notifyListeners();
  }

  void clearSelectedRt() {
    _selectedRtName = null;
    _selectedRtKeterangan = null;
    notifyListeners();
  }

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

  Future<void> loadRtBoundaries() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/geojson/batas_rt.geojson');
      final Map<String, dynamic> data = json.decode(jsonString);
      final Set<Polygon> tempPolygons = {};

      if (data['type'] == 'FeatureCollection' && data['features'] != null) {
        final features = data['features'] as List;
        for (var i = 0; i < features.length; i++) {
          final feature = features[i];
          final geometry = feature['geometry'];
          final properties = feature['properties'] ?? {};
          if (geometry == null) continue;

          final String type = geometry['type'];
          final coordinates = geometry['coordinates'];
          if (coordinates == null) continue;

          final String nama = properties['nama'] ?? 'RT $i';
          final String strokeColorHex = properties['stroke_color'] ?? '#1E3A8A';
          final String fillColorHex = properties['fill_color'] ?? '#1E3A8A';
          final double fillOpacity = (properties['fill_opacity'] as num?)?.toDouble() ?? 0.15;

          final Color strokeColor = _parseHexColor(strokeColorHex);
          final Color fillColor = _parseHexColor(fillColorHex).withOpacity(fillOpacity);

          final String keterangan = properties['keterangan'] ?? 'Wilayah $nama';

          if (type == 'Polygon') {
            final List<LatLng> points = [];
            final ring = coordinates[0] as List;
            for (var coord in ring) {
              if (coord.length >= 2) {
                points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
              }
            }
            if (points.isNotEmpty) {
              tempPolygons.add(
                Polygon(
                  polygonId: PolygonId(nama),
                  points: points,
                  strokeColor: strokeColor,
                  strokeWidth: 2,
                  fillColor: fillColor,
                  consumeTapEvents: true,
                  onTap: () => selectRt(nama, keterangan),
                ),
              );
            }
          } else if (type == 'MultiPolygon') {
            int polyIndex = 0;
            for (var polygonCoords in coordinates) {
              final List<LatLng> points = [];
              final ring = polygonCoords[0] as List;
              for (var coord in ring) {
                if (coord.length >= 2) {
                  points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
              if (points.isNotEmpty) {
                tempPolygons.add(
                  Polygon(
                    polygonId: PolygonId('${nama}_$polyIndex'),
                    points: points,
                    strokeColor: strokeColor,
                    strokeWidth: 2,
                    fillColor: fillColor,
                    consumeTapEvents: true,
                    onTap: () => selectRt(nama, keterangan),
                  ),
                );
                polyIndex++;
              }
            }
          }
        }
      }
      _polygons = tempPolygons;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading RT boundaries: $e');
    }
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}