// lib/src/domain/entities/user_entity.dart

class UserEntity {
  final int id;
  final String name;
  final String lastname;
  final String email;
  final String phone;
  final List<String> roles;

  UserEntity({
    required this.id,
    required this.name,
    required this.lastname,
    required this.email,
    required this.phone,
    required this.roles,
  });
}