// lib/src/presentation/pages/auth/register/bloc/register_bloc.dart

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/usecases/register_usecase.dart'; // ¡Importa el caso de uso!
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  // 1. Declara el caso de uso
  final RegisterUseCase registerUseCase;

  // 2. Modifica el constructor para que lo requiera
  RegisterBloc({required this.registerUseCase}) : super(RegisterState(formKey: GlobalKey<FormState>())) {
    
    // El resto de tu lógica de 'on<...Changed>' se queda igual
    on<RegisterInitEvent>((event, emit) { /*...*/ });
    on<NameChanged>((event, emit) { /*...*/ });
    on<LastnameChanged>((event, emit) { /*...*/ });
    on<EmailChanged>((event, emit) { /*...*/ });
    on<PhoneChanged>((event, emit) { /*...*/ });
    on<PasswordChanged>((event, emit) { /*...*/ });
    on<ConfirmPasswordChanged>((event, emit) { /*...*/ });

    // 3. ¡Conecta el FormSubmit al caso de uso!
    on<FormSubmit>((event, emit) async {
      print('Name: ${state.name.value}');
      // ... (otros prints)

      // Lógica de validación
      if (state.password.value != state.confirmPassword.value) {
        // En un BLoC real, emitirías un estado de error aquí
        print('Las contraseñas no coinciden');
        return;
      }
      
      try {
        await registerUseCase.call(
          name: state.name.value,
          lastname: state.lastname.value,
          email: state.email.value,
          phone: state.phone.value,
          password: state.password.value,
        );
        print('REGISTRO EXITOSO');
      } catch (e) {
        print('ERROR EN REGISTRO: ${e.toString()}');
      }
    });

    on<FormReset>((event, emit) { /*...*/ });
  }
}