// lib/src/data/services/socket_service.dart

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

// Modelos para los eventos del WebSocket
class AmbulanceLocation {
  final int shiftId;
  final double lat;
  final double lon;
  final String timestamp;

  AmbulanceLocation({
    required this.shiftId,
    required this.lat,
    required this.lon,
    required this.timestamp,
  });

  factory AmbulanceLocation.fromJson(Map<String, dynamic> json) {
    return AmbulanceLocation(
      shiftId: json['shiftId'] ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class RequestUpdate {
  final String message;
  final Map<String, dynamic> requestDetails;

  RequestUpdate({required this.message, required this.requestDetails});

  factory RequestUpdate.fromJson(Map<String, dynamic> json) {
    return RequestUpdate(
      message: json['message'] ?? '',
      requestDetails: json['requestDetails'] ?? {},
    );
  }

  String get status => requestDetails['status'] ?? 'UNKNOWN';
}

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthenticated = false;

  // Streams para emitir eventos
  final _connectionController = StreamController<bool>.broadcast();
  final _authController = StreamController<bool>.broadcast();
  final _requestAssignedController =
      StreamController<RequestUpdate>.broadcast();
  final _ambulanceLocationController =
      StreamController<AmbulanceLocation>.broadcast();
  final _statusUpdateController = StreamController<RequestUpdate>.broadcast();
  final _newMissionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newServiceRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _requestCanceledController =
      StreamController<RequestUpdate>.broadcast();
  final _ratingCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _adminQueuesController = StreamController<void>.broadcast();
  final _userProfileUpdatedController = StreamController<void>.broadcast();

  // Getters para los streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get authStream => _authController.stream;
  Stream<RequestUpdate> get requestAssignedStream =>
      _requestAssignedController.stream;
  Stream<AmbulanceLocation> get ambulanceLocationStream =>
      _ambulanceLocationController.stream;
  Stream<RequestUpdate> get statusUpdateStream =>
      _statusUpdateController.stream;
  Stream<Map<String, dynamic>> get onNewMission => _newMissionController.stream;
  Stream<Map<String, dynamic>> get onNewServiceRequest =>
      _newServiceRequestController.stream;
  Stream<RequestUpdate> get onRequestCanceled =>
      _requestCanceledController.stream;
  Stream<Map<String, dynamic>> get onRatingCreated =>
      _ratingCreatedController.stream;
  /// Colas del administrador del sistema (empresas / cambios de contacto).
  Stream<void> get adminQueuesUpdated => _adminQueuesController.stream;

  /// Perfil del usuario autenticado actualizado en servidor (contacto, etc.).
  Stream<void> get userProfileUpdated => _userProfileUpdatedController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;

  /// Conectar al servidor WebSocket
  void connect(String token) {
    if (_socket != null && _isConnected) {
      // Ya está conectado, solo autenticar de nuevo si es necesario
      if (!_isAuthenticated) {
        _authenticate(token);
      }
      return;
    }

    _socket = io.io(
      apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _setupListeners(token);
    _socket!.connect();
  }

  void _setupListeners(String token) {
    _socket!.onConnect((_) {
      print('🔌 WebSocket conectado');
      _isConnected = true;
      _connectionController.add(true);
      _authenticate(token);
    });

    _socket!.onDisconnect((_) {
      print('🔌 WebSocket desconectado');
      _isConnected = false;
      _isAuthenticated = false;
      _connectionController.add(false);
      _authController.add(false);
    });

    _socket!.onConnectError((error) {
      print('❌ Error de conexión WebSocket: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    // Evento: Autenticación exitosa
    _socket!.on('authenticated', (data) {
      print('✅ WebSocket autenticado');
      _isAuthenticated = true;
      _authController.add(true);
    });

    // Evento: No autorizado
    _socket!.on('unauthorized', (data) {
      print('❌ WebSocket no autorizado: $data');
      _isAuthenticated = false;
      _authController.add(false);
    });

    // Evento: Solicitud asignada
    _socket!.on('request_assigned', (data) {
      print('🚑 Solicitud asignada: $data');
      try {
        final update = RequestUpdate.fromJson(data as Map<String, dynamic>);
        _requestAssignedController.add(update);
      } catch (e) {
        print('Error parseando request_assigned: $e');
      }
    });

    // Evento: Ubicación de ambulancia actualizada
    _socket!.on('ambulance_location_updated', (data) {
      print('📍 Ubicación ambulancia: $data');
      try {
        final location = AmbulanceLocation.fromJson(
          data as Map<String, dynamic>,
        );
        _ambulanceLocationController.add(location);
      } catch (e) {
        print('Error parseando ambulance_location_updated: $e');
      }
    });

    // Evento: Estado de solicitud actualizado
    _socket!.on('request_status_updated', (data) {
      print('🔄 Estado actualizado: $data');
      try {
        final update = RequestUpdate.fromJson(data as Map<String, dynamic>);
        _statusUpdateController.add(update);
      } catch (e) {
        print('Error parseando request_status_updated: $e');
      }
    });

    // Evento: Nueva misión para el conductor
    _socket!.on('new_mission', (data) {
      print('🚨 Nueva misión recibida: $data');
      try {
        _newMissionController.add(data as Map<String, dynamic>);
      } catch (e) {
        print('Error parseando new_mission: $e');
      }
    });

    // Evento: Nueva solicitud de servicio (para admins)
    _socket!.on('new_service_request', (data) {
      print('🆕 Nueva solicitud de servicio: $data');
      try {
        _newServiceRequestController.add(data as Map<String, dynamic>);
      } catch (e) {
        print('Error parseando new_service_request: $e');
      }
    });

    // Evento: Solicitud cancelada
    _socket!.on('request_canceled', (data) {
      print('❌ Solicitud cancelada: $data');
      try {
        final update = RequestUpdate.fromJson(data as Map<String, dynamic>);
        _statusUpdateController.add(update);
        _requestCanceledController.add(
          update,
        ); // También emitir al stream dedicado
      } catch (e) {
        print('Error parseando request_canceled: $e');
      }
    });

    // Evento: Nueva calificación creada
    _socket!.on('rating_created', (data) {
      print('⭐ Nueva calificación creada: $data');
      try {
        _ratingCreatedController.add(data as Map<String, dynamic>);
      } catch (e) {
        print('Error parseando rating_created: $e');
      }
    });

    _socket!.on('admin_queues_updated', (data) {
      print('🛡️ Actualización colas admin: $data');
      if (!_adminQueuesController.isClosed) {
        _adminQueuesController.add(null);
      }
    });

    _socket!.on('user_profile_updated', (data) {
      print('👤 Perfil actualizado vía socket: $data');
      if (!_userProfileUpdatedController.isClosed) {
        _userProfileUpdatedController.add(null);
      }
    });
  }

  void _authenticate(String token) {
    if (_socket == null || !_isConnected) return;

    final payload = json.encode({'token': token});
    _socket!.emit('authenticate', payload);
    print('🔐 Enviando autenticación WebSocket...');
  }

  /// Enviar ubicación del conductor al servidor
  void sendLocation({
    required int shiftId,
    required double lat,
    required double lon,
  }) {
    if (_socket == null || !_isConnected || !_isAuthenticated) {
      print('⚠️ No se puede enviar ubicación: no conectado o autenticado');
      return;
    }

    _socket!.emit('update_location', {
      'shiftId': shiftId,
      'lat': lat,
      'lon': lon,
    });
    print('📍 Ubicación enviada: lat=$lat, lon=$lon');
  }

  /// Desconectar del servidor
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
  }

  /// Cerrar todos los streams
  void dispose() {
    disconnect();
    _connectionController.close();
    _authController.close();
    _requestAssignedController.close();
    _ambulanceLocationController.close();
    _statusUpdateController.close();
    _newMissionController.close();
    _newServiceRequestController.close();
    _requestCanceledController.close();
    _ratingCreatedController.close();
    if (!_adminQueuesController.isClosed) {
      _adminQueuesController.close();
    }
    if (!_userProfileUpdatedController.isClosed) {
      _userProfileUpdatedController.close();
    }
  }
}
