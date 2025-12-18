// lib/src/data/datasources/remote/auth_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/models/auth_response_model.dart';

// Define la URL base de tu API
// Para emulador Android usa: http://10.0.2.2:3000
// Para dispositivo físico usa tu IP local: http://192.168.x.x:3000
const String apiUrl = 'http://10.0.2.2:3000';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(Map<String, dynamic> userData);
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastname,
    required String phone,
    String? imageUrl,
    required String token,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  });
  Future<void> updateFcmToken({
    required String fcmToken,
    required String token,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$apiUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return AuthResponseModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  @override
  Future<AuthResponseModel> register(Map<String, dynamic> userData) async {
    final response = await client.post(
      Uri.parse('$apiUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(userData),
    );

    if (response.statusCode == 201) {
      return AuthResponseModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastname,
    required String phone,
    String? imageUrl,
    required String token,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'lastname': lastname,
      'phone': phone,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['imageUrl'] = imageUrl;
    }

    final response = await client.patch(
      Uri.parse('$apiUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al actualizar perfil');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/users/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al cambiar contraseña');
    }
  }
}
