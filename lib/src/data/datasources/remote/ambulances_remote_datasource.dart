// lib/src/data/datasources/remote/ambulances_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

abstract class AmbulancesRemoteDataSource {
  Future<List<Map<String, dynamic>>> getMyCompanyAmbulances({required String token});
}

class AmbulancesRemoteDataSourceImpl implements AmbulancesRemoteDataSource {
  final http.Client client;

  AmbulancesRemoteDataSourceImpl({required this.client});

  @override
  Future<List<Map<String, dynamic>>> getMyCompanyAmbulances({required String token}) async {
    final response = await client.get(
      Uri.parse('$apiUrl/ambulances/my-company'),
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
      throw Exception(errorBody['message'] ?? 'Error al obtener ambulancias');
    }
  }
}

