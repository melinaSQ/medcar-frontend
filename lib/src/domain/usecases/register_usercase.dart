// lib/src/domain/usecases/register_usecase.dart

import 'package:medcar_frontend/src/domain/entities/auth_response_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  // El DTO de registro tiene más campos
  Future<AuthResponseEntity> call({
    required String name,
    required String lastname,
    required String email,
    required String phone,
    required String password,
  }) async {
    final userData = {
      "name": name,
      "lastname": lastname,
      "email": email,
      "phone": phone,
      "password": password,
    };
    return await _repository.register(userData);
  }
}
