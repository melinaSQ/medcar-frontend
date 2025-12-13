// ignore_for_file: annotate_overrides

import '../../domain/entities/user_entity.dart';

// UserModel extiende UserEntity para heredar sus propiedades
class UserModel extends UserEntity {
  
  // Constructor corregido usando 'super parameters'
  UserModel({
    required super.id,
    required super.name,
    required super.lastname,
    required super.email,
    required super.phone,
    required super.roles,
  });

  // Factory constructor para crear una instancia desde un JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"] ?? 0,
      name: json["name"] ?? '',
      lastname: json["lastname"] ?? '',
      email: json["email"] ?? '',
      phone: json["phone"] ?? '',
      roles: json["roles"] != null 
          ? List<String>.from(json["roles"].map((x) => x.toString()))
          : [],
    );
  }

  // Método para convertir nuestra instancia a un Map (útil para enviar datos a la API)
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "lastname": lastname,
    "email": email,
    "phone": phone,
    "roles": roles,
  };
}