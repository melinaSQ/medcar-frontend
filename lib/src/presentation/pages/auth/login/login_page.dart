// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_content.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    // Limpiar el formulario cuando se muestra la página de login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoginBloc>().add(ResetLoginForm());
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.formStatus == FormStatus.success) {
            context.read<LoginBloc>().add(ResetFormStatus());
            // Ir a selección de roles
            Navigator.pushNamedAndRemoveUntil(
              context, 
              'roles', 
              (route) => false,
            );
          } else if (state.formStatus == FormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Error al iniciar sesión'),
                backgroundColor: Colors.red,
              ),
            );
            context.read<LoginBloc>().add(ResetFormStatus());
          }
        },
        child: BlocBuilder<LoginBloc, LoginState>(
          builder: (context, state) {
            return Stack(
              children: [
                LoginContent(state),
                if (state.formStatus == FormStatus.loading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}