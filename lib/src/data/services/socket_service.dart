// lib/src/data/services/socket_service.dart

// ignore_for_file: avoid_print

import 'dart:async';
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

  static double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int _readInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory AmbulanceLocation.fromJson(Map<String, dynamic> json) {
    final lat = _readDouble(json['lat']) ??
        _readDouble(json['latitude']);
    final lon = _readDouble(json['lon']) ??
        _readDouble(json['longitude']) ??
        _readDouble(json['lng']);
    if (lat == null || lon == null) {
      throw FormatException(
        'ambulance_location_updated sin lat/lon válidos: $json',
      );
    }
    return AmbulanceLocation(
      shiftId: _readInt(json['shiftId']),
      lat: lat,
      lon: lon,
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

class RequestUpdate {
  final String message;
  final Map<String, dynamic> requestDetails;

  RequestUpdate({required this.message, required this.requestDetails});

  factory RequestUpdate.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['requestDetails'];
    Map<String, dynamic> details = {};
    if (rawDetails is Map<String, dynamic>) {
      details = rawDetails;
    } else if (rawDetails is Map) {
      details = Map<String, dynamic>.from(rawDetails);
    }
    return RequestUpdate(
      message: json['message']?.toString() ?? '',
      requestDetails: details,
    );
  }

  String get status => requestDetails['status'] ?? 'UNKNOWN';
}

/// Socket.IO puede entregar `Map<dynamic, dynamic>`; el cast directo a
/// `Map<String, dynamic>` falla y se pierden eventos (p. ej. nuevas solicitudes).
Map<String, dynamic>? _coerceSocketMap(dynamic data) {
  if (data == null) return null;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
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
      // Volver a autenticar siempre: asegura `user_<id>` y salas correctas tras
      // cambiar de pantalla / token refrescado (antes se omitía y el cliente no recibía eventos).
      _authenticate(token);
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
      print('❌ WebSocket no autorizado');
      _isAuthenticated = false;
      _authController.add(false);
    });

    // Evento: Solicitud asignada
    _socket!.on('request_assigned', (data) {
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando request_assigned: formato inesperado');
        return;
      }
      final details = _coerceSocketMap(map['requestDetails']);
      print(
        '🚑 Solicitud asignada: id=${details?['id']}, '
        'status=${details?['status']}',
      );
      try {
        final update = RequestUpdate.fromJson(map);
        _requestAssignedController.add(update);
      } catch (e) {
        print('Error parseando request_assigned: $e');
      }
    });

    // Evento: Ubicación de ambulancia actualizada
    _socket!.on('ambulance_location_updated', (data) {
      print('📍 Ubicación ambulancia: $data');
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando ambulance_location_updated: formato inesperado');
        return;
      }
      try {
        final location = AmbulanceLocation.fromJson(map);
        _ambulanceLocationController.add(location);
      } catch (e) {
        print('Error parseando ambulance_location_updated: $e');
      }
    });

    // Evento: Estado de solicitud actualizado
    _socket!.on('request_status_updated', (data) {
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando request_status_updated: formato inesperado');
        return;
      }
      final details = _coerceSocketMap(map['requestDetails']);
      print(
        '🔄 Estado actualizado: id=${details?['id']}, '
        'status=${details?['status']}',
      );
      try {
        final update = RequestUpdate.fromJson(map);
        _statusUpdateController.add(update);
      } catch (e) {
        print('Error parseando request_status_updated: $e');
      }
    });

    // Evento: Nueva misión para el conductor
    _socket!.on('new_mission', (data) {
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando new_mission: formato inesperado');
        return;
      }
      final details = _coerceSocketMap(map['requestDetails']);
      print(
        '🚨 Nueva misión recibida: id=${details?['id']}, '
        'status=${details?['status']}',
      );
      try {
        _newMissionController.add(map);
      } catch (e) {
        print('Error parseando new_mission: $e');
      }
    });

    // Evento: Nueva solicitud de servicio (para admins)
    _socket!.on('new_service_request', (data) {
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando new_service_request: formato inesperado');
        return;
      }
      final details = _coerceSocketMap(map['requestDetails']);
      print(
        '🆕 Nueva solicitud de servicio: id=${details?['id']}, '
        'status=${details?['status']}',
      );
      try {
        _newServiceRequestController.add(map);
      } catch (e) {
        print('Error parseando new_service_request: $e');
      }
    });

    // Evento: Solicitud cancelada
    _socket!.on('request_canceled', (data) {
      print('❌ Solicitud cancelada: $data');
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando request_canceled: formato inesperado');
        return;
      }
      try {
        final update = RequestUpdate.fromJson(map);
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
      final map = _coerceSocketMap(data);
      if (map == null) {
        print('Error parseando rating_created: formato inesperado');
        return;
      }
      try {
        _ratingCreatedController.add(map);
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

    // Objeto: socket_io_client + Nest suelen entregar esto como { token } en el servidor.
    _socket!.emit('authenticate', {'token': token});
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
