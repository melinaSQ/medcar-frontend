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

  void _showLoginFailureDialog(String? rawMessage) {
    final text = (rawMessage ?? 'Error al iniciar sesión')
        .replaceAll('Exception: ', '')
        .trim();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('No se pudo iniciar sesión'),
        content: SingleChildScrollView(
          child: Text(
            text.isEmpty ? 'Vuelve a intentar o contacta al administrador.' : text,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<LoginBloc>().add(ResetFormStatus());
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.formStatus == FormStatus.success) {
            final roles = List<String>.from(state.userRoles);
            context.read<LoginBloc>().add(ResetFormStatus());
            // Solo administrador del sistema: ir directo al panel (sin menú de roles)
            final r0 = roles.isEmpty ? '' : roles.first.toUpperCase();
            final onlySystemAdmin = roles.length == 1 &&
                (r0 == 'ADMIN' || r0 == 'SYSTEM_ADMIN');
            Navigator.pushNamedAndRemoveUntil(
              context,
              onlySystemAdmin ? 'admin/home' : 'roles',
              (route) => false,
            );
          } else if (state.formStatus == FormStatus.failure) {
            _showLoginFailureDialog(state.errorMessage);
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