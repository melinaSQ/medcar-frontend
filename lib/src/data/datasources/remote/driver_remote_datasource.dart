// lib/src/data/datasources/remote/driver_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

abstract class DriverRemoteDataSource {
  Future<Map<String, dynamic>> startShift({
    required String plate,
    required String code,
    required String token,
  });

  Future<Map<String, dynamic>> endShift({required String token});

  Future<Map<String, dynamic>> updateRequestStatus({
    required int requestId,
    required String status,
    required String token,
  });
}

class DriverRemoteDataSourceImpl implements DriverRemoteDataSource {
  final http.Client client;

  DriverRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> startShift({
    required String plate,
    required String code,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/shifts/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'plate': plate,
        'code': code,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al iniciar turno');
    }
  }

  @override
  Future<Map<String, dynamic>> endShift({required String token}) async {
    final response = await client.post(
      Uri.parse('$apiUrl/shifts/end'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al finalizar turno');
    }
  }

  @override
  Future<Map<String, dynamic>> updateRequestStatus({
    required int requestId,
    required String status,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/service-requests/$requestId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'status': status}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al actualizar estado');
    }
  }
}

