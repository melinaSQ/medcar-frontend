// lib/src/data/datasources/remote/auth_remote_datasource.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/models/auth_response_model.dart';

// Puedes sobreescribirlo al ejecutar Flutter con --dart-define=API_URL=...
// Por defecto usa la dirección del host vista desde el emulador Android.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://192.168.1.18:3000',
);

// Define la URL base de tu API
//const String apiUrl = 'http://10.0.2.2:3000'; //emuladorr desde linux
//const String apiUrl = 'http://192.168.1.18:3000'; //celular fisico desde linux
//const String apiUrl = 'http://10.80.130.202';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(Map<String, dynamic> userData);
  Future<Map<String, dynamic>> getCurrentUser({required String token});
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String lastname,
    String? phone,
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
  Future<void> requestContactChange({
    String? email,
    String? phone,
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
    }
    throw Exception(_extractErrorMessage(response));
  }

  @override
  Future<Map<String, dynamic>> getCurrentUser({required String token}) async {
    final response = await client.get(
      Uri.parse('$apiUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
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
    String? phone,
    String? imageUrl,
    required String token,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'lastname': lastname,
    };
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }
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

  @override
  Future<void> updateFcmToken({
    required String fcmToken,
    required String token,
  }) async {
    final response = await client.post(
      Uri.parse('$apiUrl/users/fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'fcmToken': fcmToken}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // No lanzamos excepción para que no afecte el flujo de login
      // Solo logueamos el error
      debugPrint('Error al actualizar token FCM: ${response.body}');
    }
  }

  @override
  Future<void> requestContactChange({
    String? email,
    String? phone,
    required String token,
  }) async {
    final body = <String, dynamic>{};
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    if (body.isEmpty) {
      throw Exception('Debes proporcionar correo o celular');
    }

    final response = await client.patch(
      Uri.parse('$apiUrl/users/me/request-contact-change'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'];
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
        return message.toString();
      }
    } catch (_) {}
    return 'Error ${response.statusCode}: ${response.body}';
  }
}
