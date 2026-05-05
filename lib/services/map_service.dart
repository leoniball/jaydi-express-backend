import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  // Token de acceso de Jaydi
  static const String _mapboxToken = 'pk.eyJ1IjoiamF5ZGkwMTA3IiwiYSI6ImNtbnc0enZrODA0a28ycG9qZDZjb2ZvbncifQ.apknCKbmIRshcUZZSWMOFg';
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  /// 1. OBTENER LA RUTA (POLYLINE)
  /// Devuelve una lista de puntos para dibujar la línea azul en el mapa
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // Usamos geometries=geojson para obtener las coordenadas exactas del trazado
    final url = '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$_mapboxToken';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] == null || data['routes'].isEmpty) return [];

        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];

        // Mapbox devuelve [longitud, latitud], lo convertimos a LatLng(lat, long) compatible con FlutterMap
        return coords.map((c) => LatLng(
          double.parse(c[1].toString()), 
          double.parse(c[0].toString())
        )).toList();
      } else {
        debugPrint('Error en Mapbox (Ruta): ${response.reasonPhrase}');
        return [];
      }
    } catch (e) {
      debugPrint('Error de red en MapService: $e');
      return [];
    }
  }

  /// 2. OBTENER INFO DEL VIAJE (DISTANCIA Y TIEMPO)
  /// Útil para mostrar "Llegas en 10 min" o "Faltan 2.5 km"
  static Future<Map<String, dynamic>?> getRouteInfo(LatLng start, LatLng end) async {
    final url = '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?access_token=$_mapboxToken';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] == null || data['routes'].isEmpty) return null;

        final route = data['routes'][0];
        
        // Devolvemos los datos ya procesados para facilitar el uso en la UI de Jaydi
        return {
          'distance': route['distance'], // En metros
          'duration': route['duration'], // En segundos
          'distance_km': (route['distance'] / 1000).toStringAsFixed(1), // Ej: "5.2"
          'duration_min': (route['duration'] / 60).round(), // Ej: 12
        };
      }
    } catch (e) {
      debugPrint('Error obteniendo info de ruta: $e');
    }
    return null;
  }
}