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
}

