import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutingService {
  /// Mengambil rute antara dua titik koordinat LatLng menggunakan OSRM API (gratis, driving profile).
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final HttpClient client = HttpClient();
    try {
      // OSRM URL format: longitude,latitude
      final Uri url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline'
      );
      
      final HttpClientRequest request = await client.getUrl(url);
      final HttpClientResponse response = await request.close();
      
      if (response.statusCode == 200) {
        final String responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(responseBody);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['geometry'] as String;
          return _decodePolyline(encodedPolyline);
        }
      }
    } catch (e) {
      // Log error jika terjadi kegagalan koneksi atau parsing
      debugPrint('RoutingService Error: $e');
    } finally {
      client.close();
    }
    return [];
  }

  /// Mendekode Google-encoded polyline string menjadi `List<LatLng>`.
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }
}
