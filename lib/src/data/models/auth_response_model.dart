// lib/src/data/models/auth_response_model.dart
import '../../domain/entities/auth_response_entity.dart';
import 'user_model.dart';

class AuthResponseModel extends AuthResponseEntity {
  AuthResponseModel({required super.user, required super.accessToken});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson == null) {
      throw Exception('La respuesta no contiene datos del usuario');
    }
    return AuthResponseModel(
      user: UserModel.fromJson(userJson as Map<String, dynamic>),
      accessToken: json['accessToken'] ?? '',
    );
  }
}