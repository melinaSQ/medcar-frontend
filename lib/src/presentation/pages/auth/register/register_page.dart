import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/bloc/register_state.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/register_content.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<RegisterBloc, RegisterState>(
        builder: (context, state) {
          return RegisterContent(state);
        },
      ),
    );
  }
}
