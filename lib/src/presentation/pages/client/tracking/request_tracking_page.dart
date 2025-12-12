// lib/src/presentation/pages/client/tracking/request_tracking_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/repositories/service_request_repository.dart';

class RequestTrackingPage extends StatefulWidget {
  final double userLat;
  final double userLng;
  final int? requestId;

  const RequestTrackingPage({
    super.key,
    required this.userLat,
    required this.userLng,
    this.requestId,
  });

  @override
  State<RequestTrackingPage> createState() => _RequestTrackingPageState();
}

class _RequestTrackingPageState extends State<RequestTrackingPage> {
  final SocketService _socketService = SocketService();
  GoogleMapController? _mapController;
  
  String _currentStatus = 'SEARCHING';
  String _statusMessage = 'Buscando ambulancia disponible...';
  LatLng? _ambulancePosition;
  bool _isConnected = false;
  bool _isCanceling = false;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  StreamSubscription? _connectionSub;
  StreamSubscription? _authSub;
  StreamSubscription? _assignedSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _connectWebSocket();
  }

  void _initializeMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(widget.userLat, widget.userLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ),
    };
  }

  Future<void> _connectWebSocket() async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      
      if (session == null) {
        _showError('No hay sesión activa');
        return;
      }

      // Escuchar eventos
      _connectionSub = _socketService.connectionStream.listen((connected) {
        setState(() => _isConnected = connected);
      });

      _authSub = _socketService.authStream.listen((authenticated) {
        if (authenticated) {
          setState(() {
            _statusMessage = 'Conectado. Buscando ambulancia...';
          });
        }
      });

      _assignedSub = _socketService.requestAssignedStream.listen((update) {
        setState(() {
          _currentStatus = 'ASSIGNED';
          _statusMessage = update.message;
        });
        _showSnackBar('🚑 ${update.message}');
      });

      _locationSub = _socketService.ambulanceLocationStream.listen((location) {
        _updateAmbulancePosition(location.lat, location.lon);
      });

      _statusSub = _socketService.statusUpdateStream.listen((update) {
        _handleStatusUpdate(update);
      });

      // Conectar
      _socketService.connect(session.accessToken);
      
    } catch (e) {
      _showError('Error al conectar: $e');
    }
  }

  void _updateAmbulancePosition(double lat, double lng) {
    setState(() {
      _ambulancePosition = LatLng(lat, lng);
      
      // Actualizar marcador de ambulancia
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'ambulance_location'),
        Marker(
          markerId: const MarkerId('ambulance_location'),
          position: _ambulancePosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Ambulancia'),
        ),
      };

      // Dibujar línea entre ambulancia y usuario
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_ambulancePosition!, LatLng(widget.userLat, widget.userLng)],
          color: Colors.blue,
          width: 4,
        ),
      };
    });

    // Ajustar cámara para mostrar ambos puntos
    _fitBounds();
  }

  void _fitBounds() {
    if (_mapController == null || _ambulancePosition == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _ambulancePosition!.latitude < widget.userLat ? _ambulancePosition!.latitude : widget.userLat,
        _ambulancePosition!.longitude < widget.userLng ? _ambulancePosition!.longitude : widget.userLng,
      ),
      northeast: LatLng(
        _ambulancePosition!.latitude > widget.userLat ? _ambulancePosition!.latitude : widget.userLat,
        _ambulancePosition!.longitude > widget.userLng ? _ambulancePosition!.longitude : widget.userLng,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _handleStatusUpdate(RequestUpdate update) {
    setState(() {
      _currentStatus = update.status;
      _statusMessage = update.message;
    });

    if (update.status == 'COMPLETED') {
      _showCompletedDialog();
    } else if (update.status == 'CANCELED') {
      _showCanceledDialog();
    }
  }

  void _showCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('Servicio Completado'),
          ],
        ),
        content: const Text('El servicio de ambulancia ha sido completado exitosamente.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Volver a home
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showCanceledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Servicio Cancelado'),
          ],
        ),
        content: const Text('El servicio ha sido cancelado.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest() async {
    if (widget.requestId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar solicitud?'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta solicitud de ambulancia?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCanceling = true);

    try {
      final repository = sl<ServiceRequestRepository>();
      await repository.cancelServiceRequest(requestId: widget.requestId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud cancelada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cancelar: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() => _isCanceling = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF652580),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _authSub?.cancel();
    _assignedSub?.cancel();
    _locationSub?.cancel();
    _statusSub?.cancel();
    _socketService.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seguimiento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Indicador de conexión
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.greenAccent : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de estado
          _buildStatusPanel(),
          
          // Mapa
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.userLat, widget.userLng),
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Icono y estado
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Barra de progreso
          _buildProgressBar(),

          // Botón de cancelar (solo visible en estados que permiten cancelación)
          if (_canCancel()) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCanceling ? null : _cancelRequest,
                icon: _isCanceling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel, color: Colors.red),
                label: Text(
                  _isCanceling ? 'Cancelando...' : 'Cancelar solicitud',
                  style: TextStyle(color: _isCanceling ? Colors.grey : Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _isCanceling ? Colors.grey : Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canCancel() {
    // Solo permite cancelar cuando está buscando o recién asignado
    return _currentStatus == 'SEARCHING' || _currentStatus == 'ASSIGNED';
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (_currentStatus) {
      case 'SEARCHING':
        icon = Icons.search;
        color = Colors.orange;
        break;
      case 'ASSIGNED':
        icon = Icons.check_circle;
        color = Colors.blue;
        break;
      case 'ON_THE_WAY':
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case 'ON_SITE':
        icon = Icons.location_on;
        color = Colors.green;
        break;
      case 'TRAVELLING':
        icon = Icons.local_hospital;
        color = Colors.purple;
        break;
      case 'COMPLETED':
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case 'CANCELED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case 'SEARCHING':
        return 'Buscando ambulancia';
      case 'ASSIGNED':
        return 'Ambulancia asignada';
      case 'ON_THE_WAY':
        return 'En camino';
      case 'ON_SITE':
        return 'Ha llegado';
      case 'TRAVELLING':
        return 'En traslado';
      case 'COMPLETED':
        return 'Completado';
      case 'CANCELED':
        return 'Cancelado';
      default:
        return 'Procesando';
    }
  }

  Widget _buildProgressBar() {
    final steps = ['SEARCHING', 'ASSIGNED', 'ON_THE_WAY', 'ON_SITE', 'TRAVELLING', 'COMPLETED'];
    final currentIndex = steps.indexOf(_currentStatus);

    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? const Color(0xFF652580) : Colors.grey[300],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 3,
                    color: isCompleted && index < currentIndex
                        ? const Color(0xFF652580)
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

