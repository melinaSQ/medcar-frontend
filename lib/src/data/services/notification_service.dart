// lib/src/data/services/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import '../../domain/repositories/auth_repository.dart';

/// Handler para cuando se recibe una notificación en primer plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingForegroundHandler(RemoteMessage message) async {
  debugPrint('Notificación recibida en primer plano: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Datos: ${message.data}');
}

/// Handler para cuando se recibe una notificación en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Notificación recibida en segundo plano: ${message.messageId}');
  debugPrint('Título: ${message.notification?.title}');
  debugPrint('Cuerpo: ${message.notification?.body}');
  debugPrint('Datos: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  // Callback para manejar la navegación cuando se toca una notificación
  Function(RemoteMessage)? onNotificationTapped;

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Configurar notificaciones locales para Android
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // Configurar notificaciones locales para iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Crear el canal de notificaciones para Android
      await _createNotificationChannel();

      // Configurar Firebase Messaging
      await _setupFirebaseMessaging();

      // Solicitar permisos
      await _requestPermissions();

      // Obtener el token FCM
      await _getFCMToken();

      _initialized = true;
      debugPrint('Servicio de notificaciones inicializado correctamente');
    } catch (e) {
      debugPrint('Error al inicializar el servicio de notificaciones: $e');
    }
  }

  /// Crea el canal de notificaciones para Android
  Future<void> _createNotificationChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      const androidChannel = AndroidNotificationChannel(
        'medcar_channel',
        'MedCar Notificaciones',
        description: 'Notificaciones de la aplicación MedCar',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Configura Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Configurar el handler para notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('=== NOTIFICACIÓN EN PRIMER PLANO ===');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Título: ${message.notification?.title}');
      debugPrint('Cuerpo: ${message.notification?.body}');
      debugPrint('Datos: ${message.data}');
      debugPrint('=====================================');

      // Siempre mostrar notificación local en primer plano
      _showLocalNotification(message);
    });

    // Configurar el handler para cuando se toca una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('=== NOTIFICACIÓN TOCADA ===');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Datos: ${message.data}');
      debugPrint('===========================');
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('=== APP ABIERTA DESDE NOTIFICACIÓN ===');
      debugPrint('Message ID: ${initialMessage.messageId}');
      debugPrint('Datos: ${initialMessage.data}');
      debugPrint('======================================');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Solicita permisos de notificaciones
  Future<void> _requestPermissions() async {
    // Para Android 13+
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Estado de permisos: ${settings.authorizationStatus}');

    // Para iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Para Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  /// Obtiene el token FCM
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Escuchar cambios en el token
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('Nuevo FCM Token: $newToken');
        // Enviar el nuevo token al backend
        await _sendTokenToBackend(newToken);
      });

      return _fcmToken;
    } catch (e) {
      debugPrint('Error al obtener el token FCM: $e');
      return null;
    }
  }

  /// Obtiene el token FCM actual
  String? get fcmToken => _fcmToken;

  /// Muestra una notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Si tiene notification payload, usarlo
    String title = message.notification?.title ?? 'MedCar';
    String body = message.notification?.body ?? '';

    // Si no tiene notification pero tiene data, intentar extraer título y cuerpo
    if (title == 'MedCar' && message.data.isNotEmpty) {
      title =
          message.data['title'] ?? message.data['type'] ?? 'Nueva notificación';
      body =
          message.data['body'] ??
          message.data['message'] ??
          'Tienes una nueva notificación';
    }

    // Si aún no hay cuerpo, usar un mensaje por defecto
    if (body.isEmpty) {
      body = 'Tienes una nueva notificación';
    }

    // Crear payload con los datos de la notificación
    final payload = jsonEncode({
      'messageId': message.messageId,
      'data': message.data,
      'sentTime': message.sentTime?.toIso8601String(),
    });

    final androidDetails = AndroidNotificationDetails(
      'medcar_channel',
      'MedCar Notificaciones',
      channelDescription: 'Notificaciones de la aplicación MedCar',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: payload,
    );

    debugPrint('Notificación local mostrada: $title - $body');
  }

  /// Maneja cuando se toca una notificación local
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('=== NOTIFICACIÓN LOCAL TOCADA ===');
    debugPrint('Payload: ${response.payload}');
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('================================');

    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final payloadData = jsonDecode(response.payload!);
        debugPrint('Datos del payload: $payloadData');
        // Aquí puedes procesar el payload y navegar según sea necesario
      } catch (e) {
        debugPrint('Error al parsear payload: $e');
      }
    }
  }

  /// Maneja cuando se toca una notificación de Firebase
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('=== MANEJANDO TAP DE NOTIFICACIÓN ===');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Tipo: ${message.data['type']}');
    debugPrint('Datos completos: ${message.data}');
    debugPrint('====================================');

    // Llamar al callback si está configurado
    if (onNotificationTapped != null) {
      onNotificationTapped!(message);
    }

    // Procesar según el tipo de notificación
    final notificationType = message.data['type'];
    if (notificationType != null) {
      debugPrint('Tipo de notificación: $notificationType');
      // Aquí puedes agregar lógica específica según el tipo
      // Por ejemplo:
      // - 'service_request' -> navegar a tracking
      // - 'ambulance_assigned' -> navegar a tracking
      // - 'request_status_update' -> actualizar estado
    }
  }

  /// Suscribe a un tema
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Suscrito al tema: $topic');
    } catch (e) {
      debugPrint('Error al suscribirse al tema $topic: $e');
    }
  }

  /// Cancela la suscripción a un tema
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Desuscrito del tema: $topic');
    } catch (e) {
      debugPrint('Error al desuscribirse del tema $topic: $e');
    }
  }

  /// Envía una notificación local programada
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medcar_channel',
      'MedCar Notificaciones',
      channelDescription: 'Notificaciones de la aplicación MedCar',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Envía el token FCM al backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final authRepository = di.sl<AuthRepository>();
      await authRepository.updateFcmToken(token);
      debugPrint('Token FCM actualizado en el backend: $token');
    } catch (e) {
      debugPrint('Error al enviar token FCM al backend: $e');
    }
  }
}
