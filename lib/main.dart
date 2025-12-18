// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/bloc_providers.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/src/presentation/pages/auth/login/login_page.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/register/register_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/client_home_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/map/client_map_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/tracking/request_tracking_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/rating/rating_page.dart';
import 'package:medcar_frontend/src/presentation/pages/client/history/client_history_page.dart';
import 'package:medcar_frontend/src/presentation/pages/company/home/company_home_page.dart';
import 'package:medcar_frontend/src/presentation/pages/driver/home/driver_home_page.dart';
import 'package:medcar_frontend/src/presentation/pages/driver/history/driver_history_page.dart';
import 'package:medcar_frontend/src/presentation/pages/driver/ratings/driver_ratings_page.dart';
import 'package:medcar_frontend/src/presentation/pages/driver/shifts_history/driver_shifts_history_page.dart';
import 'package:medcar_frontend/src/presentation/pages/profile/profile_page.dart';
import 'package:medcar_frontend/src/presentation/pages/roles/role_selection_page.dart';
import 'package:medcar_frontend/src/presentation/pages/splash/splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:medcar_frontend/src/data/services/notification_service.dart';

// Handler para notificaciones en segundo plano (debe ser una función de nivel superior)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Notificación recibida en segundo plano: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Datos: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configurar el handler de notificaciones en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar el servicio de notificaciones
  await NotificationService().initialize();

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
          'roles': (BuildContext context) => const RoleSelectionPage(),
          'client/home': (BuildContext context) => const ClientHomePage(),
          'client/map': (BuildContext context) => const ClientMapPage(),
          'client/history': (BuildContext context) => const ClientHistoryPage(),
          'company/home': (BuildContext context) => const CompanyHomePage(),
          'driver/home': (BuildContext context) => const DriverHomePage(),
          'driver/history': (BuildContext context) => const DriverHistoryPage(),
          'driver/ratings': (BuildContext context) => const DriverRatingsPage(),
          'driver/shifts-history': (BuildContext context) =>
              const DriverShiftsHistoryPage(),
          'profile': (BuildContext context) => const ProfilePage(),
        },
        onGenerateRoute: (settings) {
          // Ruta con parámetros para tracking
          if (settings.name == 'client/tracking') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => RequestTrackingPage(
                userLat: args['userLat'],
                userLng: args['userLng'],
                requestId: args['requestId'],
              ),
            );
          }
          // Ruta con parámetros para calificación
          if (settings.name == 'client/rating') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => RatingPage(
                serviceRequestId: args['serviceRequestId'],
                driverName: args['driverName'],
                ambulancePlate: args['ambulancePlate'],
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
