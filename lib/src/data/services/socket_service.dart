// lib/src/data/services/socket_service.dart

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

  RequestUpdate({
    required this.message,
    required this.requestDetails,
  });

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
  final _requestAssignedController = StreamController<RequestUpdate>.broadcast();
  final _ambulanceLocationController = StreamController<AmbulanceLocation>.broadcast();
  final _statusUpdateController = StreamController<RequestUpdate>.broadcast();

  // Getters para los streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get authStream => _authController.stream;
  Stream<RequestUpdate> get requestAssignedStream => _requestAssignedController.stream;
  Stream<AmbulanceLocation> get ambulanceLocationStream => _ambulanceLocationController.stream;
  Stream<RequestUpdate> get statusUpdateStream => _statusUpdateController.stream;

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
        final location = AmbulanceLocation.fromJson(data as Map<String, dynamic>);
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
  }

  void _authenticate(String token) {
    if (_socket == null || !_isConnected) return;
    
    final payload = json.encode({'token': token});
    _socket!.emit('authenticate', payload);
    print('🔐 Enviando autenticación WebSocket...');
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
  }
}

