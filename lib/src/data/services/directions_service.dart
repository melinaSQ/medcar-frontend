// lib/src/data/services/directions_service.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

class DirectionsService {
  static String? lastError;

  /// Obtiene la ruta entre dos puntos
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    required String token,
  }) async {
    lastError = null;
    try {
      final response = await http
          .post(
            Uri.parse('$apiUrl/routing/directions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'originLat': origin.latitude,
              'originLng': origin.longitude,
              'destinationLat': destination.latitude,
              'destinationLng': destination.longitude,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'El backend respondió HTTP ${response.statusCode}.';
        try {
          final error = json.decode(response.body);
          if (error is Map<String, dynamic> && error['message'] != null) {
            final detail = error['message'];
            message = detail is List ? detail.join(', ') : detail.toString();
          }
        } catch (_) {
          // Keep the safe HTTP status message when the body is not JSON.
        }
        lastError = message;
        print('❌ Routing API HTTP ${response.statusCode}: $message');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final coordinates = data['coordinates'] as List?;
      if (coordinates == null || coordinates.length < 2) {
        lastError = 'El backend no devolvió una ruta válida.';
        return null;
      }
      final points = coordinates.map((coordinate) {
        final pair = coordinate as List;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();
      if (points.length < 2) {
        lastError = 'La ruta recibida no contiene suficientes puntos.';
        return null;
      }

      final distanceMeters = (data['distanceMeters'] as num?)?.round() ?? 0;
      final durationValue =
          (data['durationSeconds'] as num?)?.round() ?? 0;
      print(
        '✅ Ruta recibida del backend: ${points.length} puntos, '
        '$distanceMeters m, $durationValue s.',
      );
      return DirectionsResult(
        polylinePoints: points,
        distance: distanceMeters >= 1000
            ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
            : '$distanceMeters m',
        distanceValue: distanceMeters,
        duration: durationValue < 60
            ? '<1 min'
            : '${(durationValue / 60).ceil()} min',
        durationValue: durationValue,
      );
    } catch (e) {
      lastError = 'No se pudo conectar con el servidor de rutas.';
      print('❌ Error obteniendo ruta: $e');
      return null;
    }
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
