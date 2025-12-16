// lib/src/domain/repositories/auth_repository.dart
import '../entities/auth_response_entity.dart';

abstract class AuthRepository {
  // Devuelve la respuesta de autenticación que contiene el usuario y el token
  Future<AuthResponseEntity> login(String email, String password);
  Future<AuthResponseEntity> register(Map<String, dynamic> userData);

  // Métodos para manejar la sesión localmente
  Future<void> saveUserSession(AuthResponseEntity authResponse);
  Future<AuthResponseEntity?> getUserSession();
  Future<void> logout();

  // Actualizar perfil
  Future<AuthResponseEntity> updateProfile({
    required String name,
    required String lastname,
    required String phone,
    String? imageUrl,
  });

  // Cambiar contraseña
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
