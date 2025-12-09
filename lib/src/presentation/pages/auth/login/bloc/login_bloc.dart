// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  
  final formKey = GlobalKey<FormState>();

  LoginBloc() : super(LoginState()) {

    on<LoginInitEvent>((event, emit) {
      emit(state.copyWith(formKey: formKey));
    });
    
    on<EmailChanged>((event, emit) {
      // event.email  LO QUE EL USUARIO ESTA ESCRIBIENDO
      emit(state.copyWith(
          email: event.email,
          formKey: formKey));
    });

    on<PasswordChanged>((event, emit) {
      emit(state.copyWith(
          password: event.password,
          formKey: formKey));
    });

    on<FormSubmit>((event, emit) async {
      print('Email: ${state.email}');
      print('Password: ${state.password}');
    });

    
  }
}