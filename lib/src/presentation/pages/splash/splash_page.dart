import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Esperar un momento para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final authRepository = sl<AuthRepository>();
      final session = await authRepository.getUserSession();
      
      if (!mounted) return;
      
      if (session != null) {
        // Usuario tiene sesión activa, ir a home
        Navigator.pushReplacementNamed(context, 'client/home');
      } else {
        // No hay sesión, ir a login
        Navigator.pushReplacementNamed(context, 'login');
      }
    } catch (e) {
      // En caso de error, ir a login
      if (mounted) {
        Navigator.pushReplacementNamed(context, 'login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF652580),
              Color(0xFF5a469c),
              Color(0xFF00A099),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/img/medcar_logo_color.png',
              width: 250,
              height: 125,
            ),
            const SizedBox(height: 50),
            
            // Loading indicator
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            
            // Texto
            const Text(
              'Cargando...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

