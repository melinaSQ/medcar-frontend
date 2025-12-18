// lib/src/data/services/notification_service.dart

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

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
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Configura Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Configurar el handler para notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notificación en primer plano recibida');
      _showLocalNotification(message);
    });

    // Configurar el handler para cuando se toca una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notificación tocada: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
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
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('Nuevo FCM Token: $newToken');
        // Aquí puedes enviar el nuevo token a tu backend
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
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'medcar_channel',
      'MedCar Notificaciones',
      channelDescription: 'Notificaciones de la aplicación MedCar',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
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

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Maneja cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificación local tocada: ${response.payload}');
    // Aquí puedes navegar a una pantalla específica según el payload
  }

  /// Maneja cuando se toca una notificación de Firebase
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Manejando tap de notificación: ${message.data}');
    // Aquí puedes navegar a una pantalla específica según los datos
    // Por ejemplo:
    // if (message.data['type'] == 'service_request') {
    //   Navigator.pushNamed(context, '/client/tracking', arguments: {...});
    // }
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
}
