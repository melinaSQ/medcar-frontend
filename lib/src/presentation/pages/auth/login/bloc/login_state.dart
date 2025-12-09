import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class LoginState extends Equatable {
  final String email;
  final String password;
  //final Resource? response; 
  final GlobalKey<FormState>? formKey; //maneja el form

  const LoginState({
    this.email = "const String(error: 'Ingresa el email')",
    this.password = "const String(error: 'Ingresa el password')",
    this.formKey,
    //this.response
  });

  LoginState copyWith({
    String? email,
    String? password,
    //Resource? response,
    GlobalKey<FormState>? formKey,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      //response: response,
      formKey: formKey
    );
  }

  @override
  List<Object?> get props => [email, password, /*response*/];
}