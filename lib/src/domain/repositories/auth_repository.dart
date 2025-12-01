// lib/src/domain/repositories/auth_repository.dart
import '../entities/auth_response_entity.dart'; // Crearemos esta entidad

abstract class AuthRepository {
  // Devuelve la respuesta de autenticación que contiene el usuario y el token
  Future<AuthResponseEntity> login(String email, String password);
  Future<AuthResponseEntity> register(Map<String, dynamic> userData);
  
  // Métodos para manejar el token localmente
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> logout();
}