import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoginContent(),
    );
  }
}
