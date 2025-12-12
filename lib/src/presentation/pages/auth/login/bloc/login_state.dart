import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

enum FormStatus { initial, loading, success, failure }

class LoginState extends Equatable {
  final BlocFormItem email;
  final BlocFormItem password;
  final GlobalKey<FormState>? formKey;
  final FormStatus formStatus;
  final String? errorMessage;

  const LoginState({
    this.email = const BlocFormItem(error: 'Ingresa el email'),
    this.password = const BlocFormItem(error: 'Ingresa el password'),
    this.formKey,
    this.formStatus = FormStatus.initial,
    this.errorMessage,
  });

  LoginState copyWith({
    BlocFormItem? email,
    BlocFormItem? password,
    GlobalKey<FormState>? formKey,
    FormStatus? formStatus,
    String? errorMessage,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      formKey: formKey ?? this.formKey,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, password, formStatus, errorMessage];
}