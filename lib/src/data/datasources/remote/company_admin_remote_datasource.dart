// lib/src/data/datasources/remote/company_admin_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

abstract class CompanyAdminRemoteDataSource {
  // Ambulancias
  Future<List<Map<String, dynamic>>> getMyAmbulances({required String token});
  Future<Map<String, dynamic>> createAmbulance({
    required String plate,
    required String sedesCode,
    required String type,
    required String token,
  });
  Future<Map<String, dynamic>> updateAmbulance({
    required int ambulanceId,
    required String plate,
    required String sedesCode,
    required String type,
    required String token,
  });
  Future<void> deleteAmbulance({
    required int ambulanceId,
    required String token,
  });

  // Códigos de turno
  Future<Map<String, dynamic>> generateShiftCode({
    required int ambulanceId,
    required String token,
  });

  // Conductores
  Future<Map<String, dynamic>?> searchUserByEmail({
    required String email,
    required String token,
  });
  Future<List<Map<String, dynamic>>> getDrivers({required String token});
  Future<Map<String, dynamic>> assignDriverRole({
    required int userId,
    required String token,
  });

  Future<Map<String, dynamic>> removeDriverRole({
    required int userId,
    required String token,
  });
}

class CompanyAdminRemoteDataSourceImpl implements CompanyAdminRemoteDataSource {
  final http.Client client;

  CompanyAdminRemoteDataSourceImpl({required this.client});

  // ==================== AMBULANCIAS ====================

  @override
  Future<List<Map<String, dynamic>>> getMyAmbulances({
    required String token,
  }) async {
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
      throw Exception('Error al obtener ambulancias');
    }
  }

  @override
  Future<Map<String, dynamic>> createAmbulance({
    required String plate,
    required String sedesCode,
    required String type,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/ambulances'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'plate': plate.toUpperCase(),
        'sedesCode': sedesCode,
        'type': type,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al crear ambulancia');
    }
  }

  @override
  Future<Map<String, dynamic>> updateAmbulance({
    required int ambulanceId,
    required String plate,
    required String sedesCode,
    required String type,
    required String token,
  }) async {
    final response = await client.put(
      Uri.parse('$apiUrl/ambulances/$ambulanceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'plate': plate.toUpperCase(),
        'sedesCode': sedesCode,
        'type': type,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al actualizar ambulancia');
    }
  }

  @override
  Future<void> deleteAmbulance({
    required int ambulanceId,
    required String token,
  }) async {
    final response = await client.delete(
      Uri.parse('$apiUrl/ambulances/$ambulanceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al eliminar ambulancia');
    }
  }

  // ==================== CÓDIGOS DE TURNO ====================

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

  // ==================== CONDUCTORES ====================

  @override
  Future<Map<String, dynamic>?> searchUserByEmail({
    required String email,
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/users/search?email=$email'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = response.body;
      if (body.isEmpty || body == 'null') {
        return null;
      }
      return json.decode(body);
    } else {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDrivers({required String token}) async {
    final response = await client.get(
      Uri.parse('$apiUrl/users/drivers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener conductores');
    }
  }

  @override
  Future<Map<String, dynamic>> assignDriverRole({
    required int userId,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/users/$userId/assign-driver'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al asignar rol');
    }
  }

  @override
  Future<Map<String, dynamic>> removeDriverRole({
    required int userId,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/users/$userId/remove-driver'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al quitar rol');
    }
  }
}
