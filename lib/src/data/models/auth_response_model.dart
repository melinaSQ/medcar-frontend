// lib/src/data/models/auth_response_model.dart
import '../../domain/entities/auth_response_entity.dart';
import 'user_model.dart';

class AuthResponseModel extends AuthResponseEntity {
  AuthResponseModel({required super.user, required super.accessToken});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      // Usamos UserModel.fromJson para parsear el usuario anidado
      user: UserModel.fromJson(json['user']),
      accessToken: json['accessToken'],
    );
  }
}