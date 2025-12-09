import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_state.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_content.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // HOT RELOAD - CTRL + S
  // HOT RESTART - CTRL + Shift + F5
  // FULL RESTART

  LoginBloc _bloc = LoginBloc();
  @override
  Widget build(BuildContext context) {
    _bloc = BlocProvider.of<LoginBloc>(context);
    return Scaffold(
      body: BlocBuilder<LoginBloc, LoginState>(
        builder: (context, state) {
          return LoginContent(_bloc.state);
        },
      ),
    );
  }
}
