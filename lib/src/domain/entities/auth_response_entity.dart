// lib/src/domain/entities/auth_response_entity.dart
import './user_entity.dart';

class AuthResponseEntity {
    final UserEntity user;
    final String accessToken;

    AuthResponseEntity({required this.user, required this.accessToken});
}