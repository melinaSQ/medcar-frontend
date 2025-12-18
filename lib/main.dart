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

// NavigatorKey global para navegación desde notificaciones
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Handler para notificaciones en segundo plano (debe ser una función de nivel superior)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('=== NOTIFICACIÓN EN SEGUNDO PLANO ===');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Datos: ${message.data}');
  debugPrint('Sent Time: ${message.sentTime}');
  debugPrint('=====================================');

  // Nota: En segundo plano, las notificaciones se muestran automáticamente
  // por el sistema operativo, pero podemos procesar los datos aquí si es necesario
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configurar el handler de notificaciones en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar el servicio de notificaciones
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Configurar el callback de navegación
  notificationService.onNotificationTapped = _handleNotificationNavigation;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: blocProviders,
      child: MaterialApp(
        navigatorKey: navigatorKey,
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

/// Maneja la navegación cuando se toca una notificación
void _handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;
  final type = data['type'] as String?;

  debugPrint('=== NAVEGANDO DESDE NOTIFICACIÓN ===');
  debugPrint('Tipo: $type');
  debugPrint('Datos: $data');
  debugPrint('====================================');

  if (type == null) {
    debugPrint('No se especificó tipo de notificación');
    return;
  }

  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    debugPrint('Navigator no disponible aún');
    return;
  }

  switch (type) {
    case 'service_request':
    case 'new_request':
      // Nueva solicitud de emergencia (para empresa/conductor)
      // Navegar a la pantalla de home de empresa o conductor
      final role = data['role'] as String?;
      if (role == 'company' || role == 'admin') {
        navigator.pushNamedAndRemoveUntil('company/home', (route) => false);
      } else if (role == 'driver') {
        navigator.pushNamedAndRemoveUntil('driver/home', (route) => false);
      }
      break;

    case 'ambulance_assigned':
    case 'request_assigned':
      // Ambulancia asignada (para cliente)
      // Navegar a la pantalla de tracking
      final requestId = data['requestId'] as String?;
      final userLat = data['userLat'] != null
          ? double.tryParse(data['userLat'].toString())
          : null;
      final userLng = data['userLng'] != null
          ? double.tryParse(data['userLng'].toString())
          : null;

      if (requestId != null && userLat != null && userLng != null) {
        navigator.pushNamed(
          'client/tracking',
          arguments: {
            'requestId': requestId,
            'userLat': userLat,
            'userLng': userLng,
          },
        );
      } else {
        navigator.pushNamedAndRemoveUntil('client/home', (route) => false);
      }
      break;

    case 'request_status_update':
    case 'status_update':
      // Actualización de estado (para cliente/conductor)
      final requestId = data['requestId'] as String?;
      // final status = data['status'] as String?; // Puede usarse para lógica futura
      final role = data['role'] as String?;

      if (role == 'client' && requestId != null) {
        // Si es cliente y hay requestId, ir a tracking
        final userLat = data['userLat'] != null
            ? double.tryParse(data['userLat'].toString())
            : null;
        final userLng = data['userLng'] != null
            ? double.tryParse(data['userLng'].toString())
            : null;

        if (userLat != null && userLng != null) {
          navigator.pushNamed(
            'client/tracking',
            arguments: {
              'requestId': requestId,
              'userLat': userLat,
              'userLng': userLng,
            },
          );
        } else {
          navigator.pushNamedAndRemoveUntil('client/home', (route) => false);
        }
      } else if (role == 'driver') {
        navigator.pushNamedAndRemoveUntil('driver/home', (route) => false);
      }
      break;

    case 'service_completed':
    case 'request_completed':
      // Servicio completado (para cliente - mostrar pantalla de calificación)
      final serviceRequestId = data['serviceRequestId'] as String?;
      final driverName = data['driverName'] as String?;
      final ambulancePlate = data['ambulancePlate'] as String?;

      if (serviceRequestId != null &&
          driverName != null &&
          ambulancePlate != null) {
        navigator.pushNamed(
          'client/rating',
          arguments: {
            'serviceRequestId': serviceRequestId,
            'driverName': driverName,
            'ambulancePlate': ambulancePlate,
          },
        );
      } else {
        navigator.pushNamedAndRemoveUntil('client/home', (route) => false);
      }
      break;

    case 'shift_started':
    case 'shift_ended':
      // Turno iniciado/finalizado (para conductor)
      navigator.pushNamedAndRemoveUntil('driver/home', (route) => false);
      break;

    case 'message':
    case 'general':
    default:
      // Notificación general - ir a home según el rol
      final role = data['role'] as String?;
      if (role == 'client') {
        navigator.pushNamedAndRemoveUntil('client/home', (route) => false);
      } else if (role == 'company' || role == 'admin') {
        navigator.pushNamedAndRemoveUntil('company/home', (route) => false);
      } else if (role == 'driver') {
        navigator.pushNamedAndRemoveUntil('driver/home', (route) => false);
      }
      break;
  }
}
