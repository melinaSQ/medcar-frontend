// lib/src/presentation/pages/auth/login/bloc/login_bloc.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/usecases/login_usecase.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

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
        final authResponse = await loginUseCase.call(
          email: state.email.value, 
          password: state.password.value
        );
        emit(state.copyWith(
          formStatus: FormStatus.success,
          userRoles: authResponse.user.roles,
        ));
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

    on<ResetLoginForm>((event, emit) {
      // Crear un nuevo formKey para forzar la reconstrucción del formulario
      emit(LoginState(
        formKey: GlobalKey<FormState>(),
        email: const BlocFormItem(error: 'Ingresa el email'),
        password: const BlocFormItem(error: 'Ingresa el password'),
        formStatus: FormStatus.initial,
      ));
    });
  }
}