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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lastname': lastname,
    'email': email,
    'phone': phone,
    'roles': roles,
  };

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
    id: json['id'],
    name: json['name'],
    lastname: json['lastname'],
    email: json['email'],
    phone: json['phone'],
    roles: List<String>.from(json['roles']),
  );
}