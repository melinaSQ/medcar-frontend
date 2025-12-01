// lib/src/data/datasources/remote/auth_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/models/auth_response_model.dart';

// Define la URL base de tu API
const String API_URL = 'http://192.168.1.7:3000'; // ¡USA TU IP LOCAL!

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(Map<String, dynamic> userData);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$API_URL/auth/login'),
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
      Uri.parse('$API_URL/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(userData),
    );

    if (response.statusCode == 201) {
      return AuthResponseModel.fromJson(json.decode(response.body));
    } else {
      // Aquí puedes manejar errores específicos, como el 409 Conflict
      throw Exception('Failed to register: ${response.body}');
    }
  }
}