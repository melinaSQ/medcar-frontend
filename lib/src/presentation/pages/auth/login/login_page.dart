import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_content.dart';

class LoginPage extends StatelessWidget { // <--- Cambiado a StatelessWidget
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<LoginBloc, LoginState>(
        builder: (context, state) {
          // El LoginContent que ya tienes, ahora recibe el 'state'
          // directamente del BlocBuilder.
          return LoginContent(state); 
        },
      ),
    );
  }
}