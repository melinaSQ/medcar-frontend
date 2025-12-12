// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/bloc_providers.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_page.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/register_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/client_home_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/map/client_map_page.dart';
import 'package:medcar_frontend/src/presentation/pages/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: blocProviders,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MedCar App',
        initialRoute: 'splash',
        routes: {
          'splash': (BuildContext context) => const SplashPage(),
          'login': (BuildContext context) => const LoginPage(),
          'register': (BuildContext context) => const RegisterPage(),
          'client/home': (BuildContext context) => const ClientHomePage(),
          'client/map': (BuildContext context) => const ClientMapPage(),
        },
      ),
    );
  }
}
