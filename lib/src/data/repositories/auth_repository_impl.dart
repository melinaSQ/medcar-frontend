// lib/src/data/repositories/auth_repository_impl.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/auth_response_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/user_model.dart';

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

  @override
  Future<AuthResponseEntity> updateProfile({
    required String name,
    required String lastname,
    required String phone,
    String? imageUrl,
  }) async {
    try {
      // Obtener el token de la sesión actual
      final currentSession = await getUserSession();
      if (currentSession == null) {
        throw Exception('No hay sesión activa');
      }

      // Actualizar el perfil
      final updatedUser = await remoteDataSource.updateProfile(
        name: name,
        lastname: lastname,
        phone: phone,
        imageUrl: imageUrl,
        token: currentSession.accessToken,
      );

      // Crear nueva respuesta de autenticación con el usuario actualizado
      final updatedAuthResponse = AuthResponseEntity(
        user: UserModel.fromJson(updatedUser),
        accessToken: currentSession.accessToken,
      );

      // Guardar la sesión actualizada
      await saveUserSession(updatedAuthResponse);

      return updatedAuthResponse;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Obtener el token de la sesión actual
      final currentSession = await getUserSession();
      if (currentSession == null) {
        throw Exception('No hay sesión activa');
      }

      // Cambiar la contraseña
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        token: currentSession.accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }
}
