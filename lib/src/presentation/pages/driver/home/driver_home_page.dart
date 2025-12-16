// lib/src/presentation/pages/driver/home/driver_home_page.dart

// ignore_for_file: avoid_print, deprecated_member_use, unnecessary_brace_in_string_interps, sort_child_properties_last

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/driver_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/ratings_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/directions_service.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'bloc/driver_home_bloc.dart';
import 'bloc/driver_home_event.dart';
import 'bloc/driver_home_state.dart';

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DriverHomeBloc(
        authRepository: sl<AuthRepository>(),
        driverDataSource: sl<DriverRemoteDataSource>(),
      )..add(DriverHomeInitEvent()),
      child: const _DriverHomeView(),
    );
  }
}

class _DriverHomeView extends StatefulWidget {
  const _DriverHomeView();

  @override
  State<_DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<_DriverHomeView> {
  final SocketService _socketService = SocketService();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  GoogleMapController? _mapController;
  Timer? _locationTimer;
  StreamSubscription? _missionSub;
  StreamSubscription? _canceledSub;
  StreamSubscription? _statusUpdateSub;
  StreamSubscription? _ratingCreatedSub;
  int? _currentShiftId;

  // Flag para evitar procesar cancelación múltiples veces
  bool _isProcessingCancellation = false;

  // Ruta y ETA
  Set<Polyline> _polylines = {};
  String? _eta;
  String? _distance;
  LatLng? _driverPosition;

  // Calificación del conductor
  double? _driverRating;
  int _driverRatingCount = 0;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _loadDriverRating();
  }

  Future<void> _loadDriverRating() async {
    print('⭐ Conductor: _loadDriverRating llamado');
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        print(
          '⭐ Conductor: Cargando calificación para userId: ${session.user.id}',
        );
        final ratingsDs = sl<RatingsRemoteDataSource>();
        final result = await ratingsDs.getAverageRating(
          userId: session.user.id,
          token: session.accessToken,
        );
        print('⭐ Conductor: Resultado de calificación: $result');
        if (mounted) {
          setState(() {
            _driverRating = (result['average'] as num?)?.toDouble();
            _driverRatingCount = result['count'] ?? 0;
            print(
              '⭐ Conductor: Calificación actualizada - promedio: $_driverRating, count: $_driverRatingCount',
            );
          });
        }
      }
    } catch (e) {
      print('❌ Error cargando calificación del conductor: $e');
    }
  }

  Future<void> _initWebSocket() async {
    final authRepo = sl<AuthRepository>();
    final session = await authRepo.getUserSession();

    if (session != null) {
      _socketService.connect(session.accessToken);

      // Escuchar nuevas misiones
      _missionSub = _socketService.onNewMission.listen((mission) async {
        if (mounted) {
          // Limpiar datos de misión anterior
          _clearMissionData();

          context.read<DriverHomeBloc>().receiveMission(mission);
          _showMissionDialog(mission);

          // Obtener ubicación actual y ruta inmediatamente
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            if (mounted) {
              setState(() {
                _driverPosition = LatLng(position.latitude, position.longitude);
              });
              // Pequeño delay para asegurar que el BLoC tenga la misión
              await Future.delayed(const Duration(milliseconds: 100));
              _updateRouteToClient();
            }
          } catch (e) {
            print('❌ Error obteniendo ubicación inicial: $e');
          }
        }
      });

      // Escuchar cancelaciones de solicitudes
      _canceledSub = _socketService.onRequestCanceled.listen((update) {
        print(
          '🚫 Conductor: Evento request_canceled recibido: ${update.status}',
        );
        if (mounted && !_isProcessingCancellation) {
          print('🚫 Conductor: Widget mounted, procesando cancelación...');
          _handleMissionCanceled();
        }
      });

      // También escuchar cambios de estado que indiquen cancelación
      _statusUpdateSub = _socketService.statusUpdateStream.listen((update) {
        print('📊 Conductor: Estado actualizado: ${update.status}');
        if (mounted &&
            update.status == 'CANCELED' &&
            !_isProcessingCancellation) {
          print('🚫 Conductor: Detectada cancelación via statusUpdateStream');
          _handleMissionCanceled();
        }
      });

      // Escuchar nuevas calificaciones para actualizar en tiempo real
      _ratingCreatedSub = _socketService.onRatingCreated.listen((data) {
        print('⭐ Conductor: Evento rating_created recibido: $data');
        if (mounted) {
          print('⭐ Conductor: Recargando calificación...');
          _loadDriverRating();
        }
      });
    }
  }

  /// Limpia los datos de la misión actual (polylines, ETA, distancia)
  void _clearMissionData() {
    setState(() {
      _polylines = {};
      _eta = null;
      _distance = null;
      _driverPosition = null;
    });
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Maneja cuando la misión es cancelada por el cliente
  void _handleMissionCanceled() {
    // Evitar procesar múltiples veces
    if (_isProcessingCancellation) {
      print('🚫 Ya se está procesando la cancelación, ignorando...');
      return;
    }
    _isProcessingCancellation = true;

    print('🚫 Procesando cancelación de misión...');

    // Limpiar datos de la misión
    _clearMissionData();

    // Cerrar TODOS los diálogos abiertos
    while (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Actualizar el BLoC para volver al estado de turno sin misión
    context.read<DriverHomeBloc>().add(MissionCanceledEvent());

    // Mostrar notificación al conductor
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ La solicitud fue cancelada por el cliente'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );

    // Resetear el flag después de un pequeño delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isProcessingCancellation = false;
    });
  }

  void _showMissionDialog(Map<String, dynamic> mission) {
    final requestDetails = mission['requestDetails'] as Map<String, dynamic>?;
    if (requestDetails == null) return;

    final client = requestDetails['client'] as Map<String, dynamic>?;
    final clientName = client != null
        ? '${client['name']} ${client['lastname']}'
        : 'Cliente';
    final emergencyType = requestDetails['emergencyType'] ?? 'Emergencia';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.notification_important,
              color: Colors.red,
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text('¡Nueva Misión!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo: $emergencyType',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Cliente: $clientName'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startLocationUpdates();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('¡Vamos!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startLocationUpdates() async {
    print('🚀 _startLocationUpdates called, shiftId: $_currentShiftId');

    if (_currentShiftId == null) {
      print('❌ shiftId is null, cannot send location');
      return;
    }

    // Verificar y solicitar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Permisos de ubicación denegados');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Se requieren permisos de ubicación para el seguimiento',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Permisos de ubicación denegados permanentemente');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Habilita los permisos de ubicación en Configuración',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    print('✅ Permisos de ubicación concedidos');

    // Enviar ubicación cada 5 segundos
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        print(
          '📍 Sending location: lat=${position.latitude}, lon=${position.longitude}, shiftId=$_currentShiftId',
        );
        _socketService.sendLocation(
          shiftId: _currentShiftId!,
          lat: position.latitude,
          lon: position.longitude,
        );

        // Actualizar posición del conductor y ruta
        if (mounted) {
          setState(() {
            _driverPosition = LatLng(position.latitude, position.longitude);
          });
          _updateRouteToClient();
        }
      } catch (e) {
        print('❌ Error sending location: $e');
      }
    });
  }

  Future<void> _updateRouteToClient() async {
    if (_driverPosition == null) {
      print('❌ _updateRouteToClient: driverPosition es null');
      return;
    }

    final bloc = context.read<DriverHomeBloc>();
    final state = bloc.state;

    if (state.currentMission == null) {
      print('❌ _updateRouteToClient: currentMission es null');
      return;
    }

    // Los datos pueden venir directos o dentro de requestDetails (desde WebSocket)
    final mission = state.currentMission!;
    final requestDetails =
        mission['requestDetails'] as Map<String, dynamic>? ?? mission;

    final originLocation =
        requestDetails['originLocation'] as Map<String, dynamic>?;
    if (originLocation == null) {
      print('❌ _updateRouteToClient: originLocation es null');
      return;
    }

    final coordinates = originLocation['coordinates'] as List?;
    if (coordinates == null || coordinates.length < 2) {
      print('❌ _updateRouteToClient: coordinates inválidas');
      return;
    }

    final clientPos = LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );

    print(
      '🗺️ Obteniendo ruta: Driver(${_driverPosition!.latitude}, ${_driverPosition!.longitude}) -> Client(${clientPos.latitude}, ${clientPos.longitude})',
    );

    try {
      final result = await DirectionsService.getDirections(
        origin: _driverPosition!,
        destination: clientPos,
      );

      if (result != null && mounted) {
        setState(() {
          _eta = result.duration;
          _distance = result.distance;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route_to_client'),
              points: result.polylinePoints,
              color: const Color(0xFF2E7D32),
              width: 5,
            ),
          };
        });
        print('🗺️ Ruta actualizada: $_distance, ETA: $_eta');
      } else {
        print(
          '❌ _updateRouteToClient: result es null o widget no está mounted',
        );
      }
    } catch (e) {
      print('❌ Error obteniendo ruta: $e');
    }
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _codeController.dispose();
    _locationTimer?.cancel();
    _missionSub?.cancel();
    _canceledSub?.cancel();
    _statusUpdateSub?.cancel();
    _ratingCreatedSub?.cancel();
    _socketService.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverHomeBloc, DriverHomeState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Obtener shiftId del turno activo o de la misión
        if (state.activeShift != null) {
          _currentShiftId = state.activeShift!['id'];
          print('🔑 ShiftId from activeShift: $_currentShiftId');
        }
        // También puede venir del shift dentro de la misión
        if (state.currentMission != null) {
          print('📋 Mission data: ${state.currentMission}');
          final requestDetails =
              state.currentMission!['requestDetails'] as Map<String, dynamic>?;
          final shiftData =
              requestDetails?['shift'] ?? state.currentMission!['shift'];
          if (shiftData != null && shiftData is Map<String, dynamic>) {
            _currentShiftId = shiftData['id'];
            print('🔑 ShiftId from mission: $_currentShiftId');
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${state.userName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_driverRating != null && _driverRating! > 0)
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, 'driver/ratings');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < _driverRating!.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          '${_driverRating!.toStringAsFixed(1)} (${_driverRatingCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: 'Cambiar rol',
                onPressed: () {
                  final driverState = context.read<DriverHomeBloc>().state;
                  if (driverState.currentMission != null) {
                    _showCannotChangeRoleDialog();
                  } else if (driverState.activeShift != null) {
                    _showEndShiftFirstDialog();
                  } else {
                    Navigator.pushReplacementNamed(context, 'roles');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () {
                  context.read<DriverHomeBloc>().add(LogoutEvent());
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    'login',
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, 'driver/history');
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.history, color: Color(0xFF2E7D32)),
            tooltip: 'Ver historial',
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DriverHomeState state) {
    print(
      '🔄 Building body - Status: ${state.status}, Mission: ${state.currentMission != null}',
    );

    if (state.status == DriverHomeStatus.loading ||
        state.status == DriverHomeStatus.updating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == DriverHomeStatus.noShift) {
      return _buildNoShiftView(context);
    }

    // Solo mostrar vista de misión si el status es hasMission
    // (no usar currentMission != null porque puede quedar residual)
    if (state.status == DriverHomeStatus.hasMission) {
      return _buildMissionView(context, state);
    }

    // hasShift o cualquier otro estado
    return _buildHasShiftView(context, state);
  }

  Widget _buildNoShiftView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_shipping,
                  size: 80,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Iniciar Turno',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa la placa y el código para comenzar',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _plateController,
                  decoration: InputDecoration(
                    labelText: 'Placa de la ambulancia',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Código de turno',
                    prefixIcon: const Icon(Icons.qr_code),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_plateController.text.isEmpty ||
                          _codeController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Completa todos los campos'),
                          ),
                        );
                        return;
                      }
                      context.read<DriverHomeBloc>().add(
                        StartShiftEvent(
                          plate: _plateController.text.trim(),
                          code: _codeController.text.trim(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Iniciar Turno',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHasShiftView(BuildContext context, DriverHomeState state) {
    final ambulance = state.activeShift?['ambulance'] as Map<String, dynamic>?;
    final plate = ambulance?['plate'] ?? 'N/A';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Turno Activo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ambulancia: $plate',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Esperando asignación...',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showEndShiftDialog(context),
                icon: const Icon(Icons.stop, color: Colors.red),
                label: const Text(
                  'Finalizar Turno',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionView(BuildContext context, DriverHomeState state) {
    final mission = state.currentMission;
    if (mission == null) return _buildHasShiftView(context, state);

    // Los datos pueden venir directos o dentro de requestDetails (desde WebSocket)
    final requestDetails =
        mission['requestDetails'] as Map<String, dynamic>? ?? mission;

    final client = requestDetails['client'] as Map<String, dynamic>?;
    final clientName = client != null
        ? '${client['name']} ${client['lastname']}'
        : 'Cliente';
    final clientPhone = client?['phone'] ?? 'N/A';
    final emergencyType = requestDetails['emergencyType'] ?? 'N/A';
    final description =
        requestDetails['originDescription'] ?? 'Sin descripción';
    final status = requestDetails['status'] ?? 'ASSIGNED';
    final location = requestDetails['originLocation'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as List<dynamic>?;

    return Column(
      children: [
        // Info de la misión
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: _getStatusColor(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      emergencyType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    clientName,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    clientPhone,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              if (description != 'Sin descripción') ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ],
          ),
        ),

        // ETA y distancia
        if (_eta != null && _distance != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _eta!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.route, color: Color(0xFF2E7D32), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _distance!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Mapa
        Expanded(
          child: coordinates != null
              ? GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(coordinates[1], coordinates[0]),
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('client'),
                      position: LatLng(coordinates[1], coordinates[0]),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: InfoWindow(title: 'Cliente: $clientName'),
                    ),
                    if (_driverPosition != null)
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: _driverPosition!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                        infoWindow: const InfoWindow(title: 'Tu ubicación'),
                      ),
                  },
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                )
              : const Center(child: Text('Ubicación no disponible')),
        ),

        // Botones de acción
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: state.status == DriverHomeStatus.updating
                      ? null
                      : () => _updateStatus(context, status),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getNextStatusColor(status),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state.status == DriverHomeStatus.updating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _getNextStatusAction(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateStatus(BuildContext context, String currentStatus) {
    print(
      '🔄 _updateStatus called with: $currentStatus, shiftId: $_currentShiftId',
    );
    String? nextStatus;

    switch (currentStatus) {
      case 'ASSIGNED':
        nextStatus = 'ON_THE_WAY';
        // Iniciar envío de ubicación cuando va en camino
        print('🚀 Iniciando envío de ubicación...');
        _startLocationUpdates();
        break;
      case 'ON_THE_WAY':
        nextStatus = 'ON_SITE';
        break;
      case 'ON_SITE':
        nextStatus = 'TRAVELLING';
        break;
      case 'TRAVELLING':
        nextStatus = 'COMPLETED';
        _stopLocationUpdates();
        break;
    }

    if (nextStatus != null) {
      context.read<DriverHomeBloc>().add(
        UpdateStatusEvent(newStatus: nextStatus),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'ON_THE_WAY':
        return Colors.orange;
      case 'ON_SITE':
        return Colors.green;
      case 'TRAVELLING':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getNextStatusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.orange;
      case 'ON_THE_WAY':
        return Colors.green;
      case 'ON_SITE':
        return Colors.purple;
      case 'TRAVELLING':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ASSIGNED':
        return 'ASIGNADO';
      case 'ON_THE_WAY':
        return 'EN CAMINO';
      case 'ON_SITE':
        return 'EN EL LUGAR';
      case 'TRAVELLING':
        return 'EN TRASLADO';
      default:
        return status;
    }
  }

  String _getNextStatusAction(String status) {
    switch (status) {
      case 'ASSIGNED':
        return '🚗 EN CAMINO';
      case 'ON_THE_WAY':
        return '📍 HE LLEGADO';
      case 'ON_SITE':
        return '🏥 INICIAR TRASLADO';
      case 'TRAVELLING':
        return '✅ COMPLETAR';
      default:
        return 'ACTUALIZAR';
    }
  }

  void _showEndShiftDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar Turno'),
        content: const Text('¿Estás seguro de que deseas finalizar tu turno?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _stopLocationUpdates();
              context.read<DriverHomeBloc>().add(EndShiftEvent());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Finalizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCannotChangeRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 10),
            Text('Misión Activa'),
          ],
        ),
        content: const Text(
          'No puedes cambiar de rol mientras tienes una emergencia activa.\n\n'
          'Completa la emergencia actual antes de cambiar de rol.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showEndShiftFirstDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 10),
            Text('Turno Activo'),
          ],
        ),
        content: const Text(
          'Debes finalizar tu turno antes de cambiar de rol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEndShiftDialog(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              'Finalizar Turno',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
