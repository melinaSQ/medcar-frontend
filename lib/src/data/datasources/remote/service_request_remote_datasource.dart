// lib/src/data/datasources/remote/service_request_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/entities/service_request_entity.dart';

abstract class ServiceRequestRemoteDataSource {
  Future<Map<String, dynamic>> createServiceRequest({
    required EmergencyType emergencyType,
    required double latitude,
    required double longitude,
    String? originDescription,
    required String token,
  });

  Future<void> cancelServiceRequest({
    required int requestId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getPendingRequests({required String token});

  Future<Map<String, dynamic>> assignRequest({
    required int requestId,
    required int shiftId,
    required String token,
  });
}

class ServiceRequestRemoteDataSourceImpl implements ServiceRequestRemoteDataSource {
  final http.Client client;

  ServiceRequestRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> createServiceRequest({
    required EmergencyType emergencyType,
    required double latitude,
    required double longitude,
    String? originDescription,
    required String token,
  }) async {
    final body = {
      'emergencyType': emergencyType.value,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (originDescription != null && originDescription.isNotEmpty) {
      body['originDescription'] = originDescription;
    }

    final response = await client.post(
      Uri.parse('$apiUrl/service-requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al crear la solicitud');
    }
  }

  @override
  Future<void> cancelServiceRequest({
    required int requestId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/service-requests/$requestId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al cancelar la solicitud');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingRequests({required String token}) async {
    final response = await client.get(
      Uri.parse('$apiUrl/service-requests/pending'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al obtener solicitudes');
    }
  }

  @override
  Future<Map<String, dynamic>> assignRequest({
    required int requestId,
    required int shiftId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/service-requests/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'requestId': requestId,
        'shiftId': shiftId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al asignar solicitud');
    }
  }
}

