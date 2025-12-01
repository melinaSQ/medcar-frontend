// lib/main.dart

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di; // Importa con un alias

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Aquí irá tu primera pantalla, por ejemplo, LoginPage()
      home: Scaffold(body: Center(child: Text('Setup Completo!'))),
    );
  }
}