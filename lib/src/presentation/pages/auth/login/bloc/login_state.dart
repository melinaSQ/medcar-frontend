import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:medcar_frontend/src/presentation/utils/bloc_from_item.dart';

class LoginState extends Equatable {
  final BlocFormItem email;
  final BlocFormItem password;
  //final Resource? response; 
  final GlobalKey<FormState>? formKey; //maneja el form

  const LoginState({
    this.email = const BlocFormItem(error: 'Ingresa el email'),
    this.password = const BlocFormItem(error: 'Ingresa el password'),
    this.formKey,
    //this.response
  });

  LoginState copyWith({
    BlocFormItem? email,
    BlocFormItem? password,
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