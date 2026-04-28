import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  static const String _mapboxToken = 'pk.eyJ1IjoiamF5ZGkwMTA3IiwiYSI6ImNtbnc0enZrODA0a28ycG9qZDZjb2ZvbncifQ.apknCKbmIRshcUZZSWMOFg';
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$_mapboxToken';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];

        return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      } else {
        debugPrint('Error en Mapbox: ${response.reasonPhrase}');
        return [];
      }
    } catch (e) {
      debugPrint('Error de red en MapService: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getRouteInfo(LatLng start, LatLng end) async {
    final url = '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?access_token=$_mapboxToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        return {
          'distance': route['distance'], 
          'duration': route['duration'], 
        };
      }
    } catch (e) {
      debugPrint('Error obteniendo info de ruta: $e');
    }
    return null;
  }
}