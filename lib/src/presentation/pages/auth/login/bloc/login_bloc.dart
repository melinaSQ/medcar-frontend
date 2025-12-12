// lib/src/presentation/pages/auth/login/bloc/login_bloc.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;

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
      emit(state.copyWith(formStatus: FormStatus.loading));
      
      try {
        await loginUseCase.call(
          email: state.email.value, 
          password: state.password.value
        );
        emit(state.copyWith(formStatus: FormStatus.success));
      } catch (e) {
        emit(state.copyWith(
          formStatus: FormStatus.failure,
          errorMessage: e.toString(),
        ));
      }
    });

    on<ResetFormStatus>((event, emit) {
      emit(state.copyWith(formStatus: FormStatus.initial));
    });
  }
}