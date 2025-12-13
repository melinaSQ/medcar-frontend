// lib/src/data/services/directions_service.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  // API Key de Google Maps (debe tener Directions API habilitada)
  static const String _apiKey = 'AIzaSyCFnby3-GO4JaxvIUut1-uiy8dYgmquAEw';
  
  /// Obtiene la ruta entre dos puntos
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=driving'
      '&language=es'
      '&key=$_apiKey'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decodificar la polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          return DirectionsResult(
            polylinePoints: polylinePoints,
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'],
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'],
          );
        }
      }
      
      print('❌ Error en Directions API: ${response.body}');
      return null;
    } catch (e) {
      print('❌ Error obteniendo direcciones: $e');
      return null;
    }
  }

  /// Decodifica la polyline codificada de Google
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      // Decodificar latitud
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decodificar longitud
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final int distanceValue; // en metros
  final String duration;
  final int durationValue; // en segundos

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
  });
}

