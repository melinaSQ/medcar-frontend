import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

enum RegisterFormStatus { initial, loading, success, failure }

class RegisterState extends Equatable {
  final BlocFormItem name;
  final BlocFormItem lastname;
  final BlocFormItem email;
  final BlocFormItem phone;
  final BlocFormItem password;
  final BlocFormItem confirmPassword;
  final GlobalKey<FormState>? formKey;
  final RegisterFormStatus formStatus;
  final String? errorMessage;

  const RegisterState({
    this.name = const BlocFormItem(error: 'Ingresa el nombre'),
    this.lastname = const BlocFormItem(error: 'Ingresa el apellido'),
    this.email = const BlocFormItem(error: 'Ingresa el email'),
    this.phone = const BlocFormItem(error: 'Ingresa el telefono'),
    this.password = const BlocFormItem(error: 'Ingresa el password'),
    this.confirmPassword = const BlocFormItem(error: 'Confirma la contraseña'),
    this.formKey,
    this.formStatus = RegisterFormStatus.initial,
    this.errorMessage,
  });

  RegisterState copyWith({
    BlocFormItem? name,
    BlocFormItem? lastname,
    BlocFormItem? email,
    BlocFormItem? phone,
    BlocFormItem? password,
    BlocFormItem? confirmPassword,
    GlobalKey<FormState>? formKey,
    RegisterFormStatus? formStatus,
    String? errorMessage,
  }) {
    return RegisterState(
      name: name ?? this.name,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      formKey: formKey ?? this.formKey,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [name, lastname, email, phone, password, confirmPassword, formStatus, errorMessage];
}