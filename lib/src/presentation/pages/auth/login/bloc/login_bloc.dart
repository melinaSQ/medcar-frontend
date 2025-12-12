// lib/src/presentation/pages/auth/login/bloc/login_bloc.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart'; // ¡Asegúrate de importar el caso de uso!
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  
  // 1. Declara el caso de uso como una propiedad final
  final LoginUseCase loginUseCase;

  // 2. Modifica el constructor para que requiera el caso de uso
  LoginBloc({required this.loginUseCase}) : super(LoginState(formKey: GlobalKey<FormState>())) {

    on<LoginInitEvent>((event, emit) {
      emit(state.copyWith(formKey: state.formKey));
    });
    
    on<EmailChanged>((event, emit) {
      emit(state.copyWith(email: event.email));
    });

    on<PasswordChanged>((event, emit) {
      emit(state.copyWith(password: event.password));
    });

    on<FormSubmit>((event, emit) async {
      print('Email: ${state.email.value}');
      print('Password: ${state.password.value}');
      
      try {
        // 3. ¡Ahora puedes usar el caso de uso!
        final authResponse = await loginUseCase.call(
          email: state.email.value, 
          password: state.password.value
        );
        print('LOGIN EXITOSO: ${authResponse.user.name}');
      } catch (e) {
        print('ERROR EN LOGIN: ${e.toString()}');
      }
    });
  }
}