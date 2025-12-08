// lib/main.dart

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_page.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/register_page.dart'; // Importa con un alias

void main() async {
  // Es importante asegurar que Flutter esté inicializado antes de llamar a dependencias
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos nuestro service locator
  await di.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedCar App',
      /*
      theme:(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),*/
      initialRoute: 'login',
      routes: {
        'login': (BuildContext context) => LoginPage(),
        'register': (BuildContext context) => RegisterPage(),
      },
    );
  }
}