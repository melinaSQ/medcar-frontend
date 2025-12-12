// lib/src/data/datasources/remote/shifts_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

abstract class ShiftsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getActiveShifts({required String token});
  Future<Map<String, dynamic>> generateShiftCode({
    required int ambulanceId,
    required String token,
  });
}

class ShiftsRemoteDataSourceImpl implements ShiftsRemoteDataSource {
  final http.Client client;

  ShiftsRemoteDataSourceImpl({required this.client});

  @override
  Future<List<Map<String, dynamic>>> getActiveShifts({required String token}) async {
    final response = await client.get(
      Uri.parse('$apiUrl/shifts/active'),
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
      throw Exception(errorBody['message'] ?? 'Error al obtener turnos activos');
    }
  }

  @override
  Future<Map<String, dynamic>> generateShiftCode({
    required int ambulanceId,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/shifts/generate-code'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'ambulanceId': ambulanceId}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al generar código');
    }
  }
}

