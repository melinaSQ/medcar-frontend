// lib/src/domain/usecases/login_usecase.dart

import 'package:medcar_frontend/src/domain/entities/auth_response_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository authRepository;

  LoginUseCase(this.authRepository);

  Future<AuthResponseEntity> call({required String email, required String password})async {
    // En un caso real, aquí podrías añadir lógica de negocio,
    // como validar el formato del email antes de llamar al repositorio.
    // Pero por ahora, solo delegamos.
    return await authRepository.login(email, password);
  }
}