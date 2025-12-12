// lib/src/data/repositories/auth_repository_impl.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/auth_response_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';

const String _sessionKey = 'user_session';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AuthResponseEntity> login(String email, String password) async {
    try {
      final authResponse = await remoteDataSource.login(email, password);
      await saveUserSession(authResponse);
      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthResponseEntity> register(Map<String, dynamic> userData) async {
    try {
      final authResponse = await remoteDataSource.register(userData);
      await saveUserSession(authResponse);
      return authResponse;
    } catch (e) {
      rethrow;
    }
  }

  // --- Implementación del manejo de la sesión local ---

  @override
  Future<void> saveUserSession(AuthResponseEntity authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = json.encode(authResponse.toJson());
    await prefs.setString(_sessionKey, sessionJson);
  }

  @override
  Future<AuthResponseEntity?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson == null) return null;
    
    final sessionMap = json.decode(sessionJson) as Map<String, dynamic>;
    return AuthResponseEntity.fromJson(sessionMap);
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}