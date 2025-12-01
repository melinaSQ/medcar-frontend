// lib/src/data/repositories/auth_repository_impl.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/auth_response_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';

const String _TOKEN_KEY = 'auth_token';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AuthResponseEntity> login(String email, String password) async {
    try {
      final authResponse = await remoteDataSource.login(email, password);
      // Después de un login exitoso, guarda el token
      await saveToken(authResponse.accessToken);
      return authResponse;
    } catch (e) {
      rethrow; // Propaga el error para que la capa de presentación lo maneje
    }
  }

  @override
  Future<AuthResponseEntity> register(Map<String, dynamic> userData) async {
    try {
      final authResponse = await remoteDataSource.register(userData);
      // Después de un registro exitoso, guarda el token
      await saveToken(authResponse.accessToken);
      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  // --- Implementación del manejo del token local ---

  @override
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_TOKEN_KEY, token);
  }

  @override
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_TOKEN_KEY);
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_TOKEN_KEY);
  }
}