import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_event.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_state.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/register_content.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      context.read<RegisterBloc>().add(RegisterInitEvent());
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state.formStatus == RegisterFormStatus.success) {
            context.read<RegisterBloc>().add(ResetFormStatus());
            Navigator.pushNamedAndRemoveUntil(
              context, 
              'client/home', 
              (route) => false,
            );
          } else if (state.formStatus == RegisterFormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Error al registrar'),
                backgroundColor: Colors.red,
              ),
            );
            context.read<RegisterBloc>().add(ResetFormStatus());
          }
        },
        child: BlocBuilder<RegisterBloc, RegisterState>(
          builder: (context, state) {
            return Stack(
              children: [
                RegisterContent(state),
                if (state.formStatus == RegisterFormStatus.loading)
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
