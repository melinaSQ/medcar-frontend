// lib/src/domain/entities/auth_response_entity.dart
import './user_entity.dart';

class AuthResponseEntity {
  final UserEntity user;
  final String accessToken;

  AuthResponseEntity({required this.user, required this.accessToken});

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'accessToken': accessToken,
  };

  factory AuthResponseEntity.fromJson(Map<String, dynamic> json) => AuthResponseEntity(
    user: UserEntity.fromJson(json['user']),
    accessToken: json['accessToken'],
  );
}