// lib/src/presentation/pages/client/tracking/request_tracking_page.dart

// ignore_for_file: avoid_print, deprecated_member_use, unnecessary_brace_in_string_interps

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/ratings_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/directions_service.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/repositories/service_request_repository.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/utils/map_coercion.dart';
import 'package:medcar_frontend/src/utils/service_request_status.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final SocketService _socketService = sl<SocketService>();
  GoogleMapController? _mapController;

  String _currentStatus = 'SEARCHING';
  String _statusMessage = 'Buscando ambulancia disponible...';
  LatLng? _ambulancePosition;
  bool _isConnected = false;
  bool _isCanceling = false;

  // ETA y distancia
  String? _eta;
  String? _distance;
  int _directionsRequestGen = 0;
  bool _routeLoading = false;
  bool _cameraMoving = false;
  bool _hasFittedRoute = false;
  DateTime? _lastRouteAttempt;
  String? _routeError;

  /// ID resuelto desde el API si `widget.requestId` viene vacío (notificaciones, etc.).
  int? _resolvedRequestId;

  // Datos del conductor y ambulancia para calificación
  String? _driverName;
  String? _ambulancePlate;
  int? _driverId;

  // Calificación promedio del conductor
  double? _driverRating;
  int _driverRatingCount = 0;

  // Calificación promedio de la empresa
  double? _companyRating;
  int _companyRatingCount = 0;
  int? _companyUserId;

  /// Solo dígitos (código país + número) para `wa.me`.
  String? _companyPhoneForWhatsApp;
  String? _companyContactName;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription? _connectionSub;
  StreamSubscription? _authSub;
  StreamSubscription? _assignedSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _ratingCreatedSub;
  Timer? _hydratePollTimer;

  bool _sameRequestId(dynamic a, dynamic b) {
    if (a == null || b == null) return true;
    final ai = a is int ? a : int.tryParse(a.toString());
    final bi = b is int ? b : int.tryParse(b.toString());
    return ai != null && bi != null && ai == bi;
  }

  int? get _effectiveRequestId => _resolvedRequestId ?? widget.requestId;

  @override
  void initState() {
    super.initState();
    _resolvedRequestId = widget.requestId;
    _initializeMarkers();
    _connectWebSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        _hydrateActiveRequestFromApi,
      );
    });
    _hydratePollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      if (_currentStatus == 'COMPLETED' || _currentStatus == 'CANCELED') {
        return;
      }
      _hydrateActiveRequestFromApi();
    });
  }

  /// Si el socket falló o el evento llegó antes de autenticar, el REST trae la misma solicitud con turno.
  Future<void> _hydrateActiveRequestFromApi() async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session == null || !mounted) return;
      final ds = sl<ServiceRequestRemoteDataSource>();
      final active = await ds.getActiveRequest(token: session.accessToken);
      if (!mounted || active == null) return;
      final rid = active['id'];
      if (widget.requestId != null &&
          rid != null &&
          !_sameRequestId(rid, widget.requestId)) {
        return;
      }
      final activeMap = coerceMap(active) ?? Map<String, dynamic>.from(active);
      final shift = coerceMap(activeMap['shift']);
      final msg = shift != null
          ? 'Ambulancia asignada.'
          : 'Buscando ambulancia disponible...';
      await _applyAssignedRequestDetails(
        activeMap,
        message: msg,
        showAssignedSnack: false,
      );
    } catch (e) {
      print('Hydrate active request: $e');
    }
  }

  Future<void> _applyAssignedRequestDetails(
    Map<String, dynamic> requestDetails, {
    required String message,
    bool showAssignedSnack = true,
  }) async {
    final shift = coerceMap(requestDetails['shift']);
    String? companyWaDigits;
    String? companyDisplayName;

    if (shift != null) {
      final driver = coerceMap(shift['driver']);
      final ambulance = coerceMap(shift['ambulance']);
      if (driver != null) {
        _driverName = '${driver['name'] ?? ''} ${driver['lastname'] ?? ''}'
            .trim();
        _driverId = driver['id'] is int
            ? driver['id'] as int
            : int.tryParse(driver['id']?.toString() ?? '');
        if (_driverId != null) {
          await _loadDriverRating(_driverId!);
        }
      }
      if (ambulance != null) {
        _ambulancePlate = ambulance['plate']?.toString();
        final company = coerceMap(ambulance['company']);
        if (company != null) {
          final cn = company['name']?.toString().trim();
          if (cn != null && cn.isNotEmpty) {
            companyDisplayName = cn;
          }
          companyWaDigits = _digitsForWhatsApp(company['phone']?.toString());
          final companyUser = coerceMap(company['user']);
          if (companyUser != null) {
            _companyUserId = companyUser['id'] is int
                ? companyUser['id'] as int
                : int.tryParse(companyUser['id']?.toString() ?? '');
            if (_companyUserId != null) {
              await _loadCompanyRating(_companyUserId!);
            }
          }
        }
      }
    } else {
      companyWaDigits = null;
      companyDisplayName = null;
    }

    final rid = parseServiceRequestId(requestDetails['id']);
    if (rid != null) {
      _resolvedRequestId = rid;
    }

    final status = normalizeServiceRequestStatus(
      requestDetails['status']?.toString(),
      hasAssignedShift: shift != null,
    );

    if (!mounted) return;
    setState(() {
      _currentStatus = status;
      _statusMessage = message;
      _companyPhoneForWhatsApp = companyWaDigits;
      _companyContactName = companyDisplayName;
    });
    if (showAssignedSnack) {
      _showSnackBar('🚑 $message');
    }

    await _seedAmbulanceFromShift(shift);
  }

  /// Última posición guardada en el turno (backend) cuando el socket no entrega eventos.
  Future<void> _seedAmbulanceFromShift(Map<String, dynamic>? shift) async {
    if (shift == null || !mounted) return;
    final lat = shift['lastKnownLat'] ?? shift['last_known_lat'];
    final lon = shift['lastKnownLon'] ?? shift['last_known_lon'];
    final la = lat is num
        ? lat.toDouble()
        : double.tryParse(lat?.toString() ?? '');
    final lo = lon is num
        ? lon.toDouble()
        : double.tryParse(lon?.toString() ?? '');
    if (la == null || lo == null) return;
    if (la.abs() < 1e-6 && lo.abs() < 1e-6) return;
    await _updateAmbulancePosition(la, lo);
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

  void _cancelTrackingSocketSubs() {
    _connectionSub?.cancel();
    _authSub?.cancel();
    _assignedSub?.cancel();
    _locationSub?.cancel();
    _statusSub?.cancel();
    _ratingCreatedSub?.cancel();
    _connectionSub = null;
    _authSub = null;
    _assignedSub = null;
    _locationSub = null;
    _statusSub = null;
    _ratingCreatedSub = null;
  }

  Future<void> _connectWebSocket() async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();

      if (!mounted) return;
      if (session == null) {
        _showError('No hay sesión activa');
        return;
      }

      _cancelTrackingSocketSubs();

      // Escuchar eventos
      _connectionSub = _socketService.connectionStream.listen((connected) {
        if (mounted) setState(() => _isConnected = connected);
      });

      _authSub = _socketService.authStream.listen((authenticated) async {
        if (!mounted) return;
        setState(() {
          _isConnected = authenticated && _socketService.isConnected;
          if (authenticated) {
            _statusMessage = 'Conectado. Buscando ambulancia...';
          }
        });
        if (authenticated) {
          await _hydrateActiveRequestFromApi();
        }
      });

      _assignedSub = _socketService.requestAssignedStream.listen((
        update,
      ) async {
        await _applyAssignedRequestDetails(
          update.requestDetails,
          message: update.message,
          showAssignedSnack: true,
        );
      });

      _locationSub = _socketService.ambulanceLocationStream.listen((location) {
        print(
          '📍 Cliente recibió ubicación: lat=${location.lat}, lon=${location.lon}',
        );
        _updateAmbulancePosition(location.lat, location.lon);
      });

      _statusSub = _socketService.statusUpdateStream.listen((update) {
        _handleStatusUpdate(update);
      });

      // Escuchar nuevas calificaciones para actualizar en tiempo real
      _ratingCreatedSub = _socketService.onRatingCreated.listen((data) {
        if (mounted && _driverId != null) {
          _loadDriverRating(_driverId!);
        }
        if (mounted && _companyUserId != null) {
          _loadCompanyRating(_companyUserId!);
        }
      });

      // Conectar
      _socketService.connect(session.accessToken);
      // SocketService es singleton y puede venir conectado desde la pantalla
      // principal; en ese caso no se emite un nuevo evento connectionStream.
      if (mounted) {
        setState(() => _isConnected = _socketService.isConnected);
      }
    } catch (e) {
      _showError('Error al conectar: $e');
    }
  }

  Future<void> _updateAmbulancePosition(double lat, double lng) async {
    if (!mounted ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return;
    }
    final newPosition = LatLng(lat, lng);

    setState(() {
      _ambulancePosition = newPosition;

      // Actualizar marcador de ambulancia
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'ambulance_location'),
        Marker(
          markerId: const MarkerId('ambulance_location'),
          position: _ambulancePosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Ambulancia',
            snippet: _eta != null ? 'Llega en $_eta' : null,
          ),
        ),
      };
    });

    await _getDirections(newPosition);

    if (mounted && _ambulancePosition != null) {
      setState(() {
        _markers = {
          ..._markers.where((m) => m.markerId.value != 'ambulance_location'),
          Marker(
            markerId: const MarkerId('ambulance_location'),
            position: _ambulancePosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: 'Ambulancia',
              snippet: _eta != null ? 'Llega en $_eta' : null,
            ),
          ),
        };
      });
    }

    if (!_hasFittedRoute) await _fitBounds();
  }

  Future<void> _getDirections(LatLng ambulancePos) async {
    final now = DateTime.now();
    if (_routeLoading ||
        (_lastRouteAttempt != null &&
            now.difference(_lastRouteAttempt!) < const Duration(minutes: 1))) {
      return;
    }
    _routeLoading = true;
    _lastRouteAttempt = now;
    final gen = ++_directionsRequestGen;
    try {
      final session = await sl<AuthRepository>().getUserSession();
      if (session == null) return;
      final result = await DirectionsService.getDirections(
        origin: ambulancePos,
        destination: LatLng(widget.userLat, widget.userLng),
        token: session.accessToken,
      );
      if (!mounted || gen != _directionsRequestGen) return;
      setState(() {
        if (result == null || result.polylinePoints.length < 2) {
          _routeError = DirectionsService.lastError ??
              'No se pudo actualizar la ruta por calles. Reintentando...';
          print('❌ Seguimiento: no llegó una ruta válida. $_routeError');
          return;
        }
        _routeError = null;
        _eta = result.duration;
        _distance = result.distance;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polylinePoints,
            color: const Color(0xFF652580),
            width: 6,
          ),
        };
        print(
          '✅ Seguimiento: polyline actualizada con '
          '${result.polylinePoints.length} puntos.',
        );
      });
    } finally {
      _routeLoading = false;
    }
  }

  Future<void> _fitBounds() async {
    final controller = _mapController;
    final position = _ambulancePosition;
    if (!mounted || controller == null || position == null || _cameraMoving) {
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        position.latitude < widget.userLat ? position.latitude : widget.userLat,
        position.longitude < widget.userLng
            ? position.longitude
            : widget.userLng,
      ),
      northeast: LatLng(
        position.latitude > widget.userLat ? position.latitude : widget.userLat,
        position.longitude > widget.userLng
            ? position.longitude
            : widget.userLng,
      ),
    );
    _cameraMoving = true;
    try {
      final samePoint =
          (position.latitude - widget.userLat).abs() < 0.0001 &&
          (position.longitude - widget.userLng).abs() < 0.0001;
      await controller.animateCamera(
        samePoint
            ? CameraUpdate.newLatLngZoom(position, 16)
            : CameraUpdate.newLatLngBounds(bounds, 60),
      );
      if (mounted && identical(controller, _mapController)) {
        _hasFittedRoute = true;
      }
    } catch (e) {
      print('No se pudo ajustar la cámara del mapa: $e');
    } finally {
      _cameraMoving = false;
    }
  }

  void _handleStatusUpdate(RequestUpdate update) {
    final shift = coerceMap(update.requestDetails['shift']);
    setState(() {
      _currentStatus = normalizeServiceRequestStatus(
        update.status,
        hasAssignedShift: shift != null,
      );
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
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('Servicio Completado'),
          ],
        ),
        content: const Text(
          'El servicio de ambulancia ha sido completado exitosamente.\n\n¿Te gustaría calificar el servicio?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamedAndRemoveUntil(
                context,
                'client/home',
                (route) => false,
              );
            },
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(
                context,
                'client/rating',
                arguments: {
                  'serviceRequestId': _effectiveRequestId,
                  'driverName': _driverName,
                  'ambulancePlate': _ambulancePlate,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF652580),
            ),
            child: const Text(
              'Calificar',
              style: TextStyle(color: Colors.white),
            ),
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
    final id = _effectiveRequestId;
    if (id == null) {
      _showError(
        'No se encontró el número de solicitud. Abre el seguimiento desde el inicio o recarga.',
      );
      return;
    }

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
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCanceling = true);

    try {
      final repository = sl<ServiceRequestRepository>();
      await repository.cancelServiceRequest(requestId: id);

      if (mounted) {
        context.read<ClientHomeBloc>().add(ClientHomeClearActiveRequestEvent());
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
        _showError(
          'Error al cancelar: ${e.toString().replaceAll('Exception: ', '')}',
        );
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

  /// Solo dígitos; incluir código de país en el dato de la empresa (p. ej. 593…).
  /// Solo dígitos para `wa.me`, en formato Bolivia (+591). Si el número ya empieza por 591, no se duplica.
  String? _digitsForWhatsApp(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
      if (digits.isEmpty) return null;
    }
    if (!digits.startsWith('591')) {
      digits = '591$digits';
    }
    return digits;
  }

  bool get _canShowCompanyWhatsApp {
    final p = _companyPhoneForWhatsApp;
    if (p == null || p.isEmpty) return false;
    final s = _currentStatus.toUpperCase();
    if (s == 'SEARCHING' ||
        s == 'COMPLETED' ||
        s == 'CANCELED' ||
        s == 'CANCELLED') {
      return false;
    }
    return true;
  }

  Future<void> _openCompanyWhatsApp() async {
    final n = _companyPhoneForWhatsApp;
    if (n == null || n.isEmpty) return;
    final rid = _effectiveRequestId;
    final text = rid != null
        ? 'Hola, escribo por mi servicio MedCar (solicitud #$rid).'
        : 'Hola, escribo por mi servicio MedCar.';
    final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showError('No se pudo abrir WhatsApp');
      }
    } catch (_) {
      if (mounted) {
        _showError('No se pudo abrir WhatsApp');
      }
    }
  }

  Future<void> _loadDriverRating(int driverId) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final ratingsDs = sl<RatingsRemoteDataSource>();
        final result = await ratingsDs.getAverageRating(
          userId: driverId,
          token: session.accessToken,
        );
        if (mounted) {
          setState(() {
            _driverRating = (result['average'] as num?)?.toDouble();
            _driverRatingCount = result['count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Ignorar error silenciosamente
      print('Error cargando calificación del conductor: $e');
    }
  }

  Future<void> _loadCompanyRating(int companyUserId) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final ratingsDs = sl<RatingsRemoteDataSource>();
        final result = await ratingsDs.getCompanyAverageRatingByUserId(
          companyUserId: companyUserId,
          token: session.accessToken,
        );
        if (mounted) {
          setState(() {
            _companyRating = (result['average'] as num?)?.toDouble();
            _companyRatingCount = result['count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Ignorar error silenciosamente
      print('Error cargando calificación de la empresa: $e');
    }
  }

  @override
  void dispose() {
    _hydratePollTimer?.cancel();
    _cancelTrackingSocketSubs();
    _directionsRequestGen++;
    _mapController?.dispose();
    _mapController = null;
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
              key: const ValueKey('tracking_map'),
              onMapCreated: (controller) {
                _mapController = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (_ambulancePosition != null) {
                      _fitBounds();
                    }
                  }
                });
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.userLat, widget.userLng),
                zoom: 15,
              ),
              markers: Set<Marker>.of(_markers),
              polylines: Set<Polyline>.of(_polylines),
              mapType: MapType.normal,
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
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Información del conductor (cuando está asignado)
          if (_driverName != null && _currentStatus != 'SEARCHING') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.blue,
                    radius: 20,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conductor: $_driverName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_driverRating != null && _driverRating! > 0) ...[
                          const SizedBox(height: 4),
                          Row(
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
                              const SizedBox(width: 6),
                              Text(
                                '${_driverRating!.toStringAsFixed(1)} (${_driverRatingCount})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ] else if (_driverRatingCount == 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sin calificaciones aún',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_canShowCompanyWhatsApp) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCompanyWhatsApp,
                icon: const Icon(Icons.chat, color: Colors.white),
                label: Text(
                  _companyContactName != null && _companyContactName!.isNotEmpty
                      ? 'WhatsApp: $_companyContactName'
                      : 'Contactar empresa por WhatsApp',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // Información de la empresa (cuando está asignado)
          if (_companyRating != null &&
              _companyRating! > 0 &&
              _currentStatus != 'SEARCHING') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.purple,
                    radius: 20,
                    child: Icon(Icons.business, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calificación de la empresa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < _companyRating!.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 14,
                                color: Colors.amber,
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(
                              '${_companyRating!.toStringAsFixed(1)} (${_companyRatingCount})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_routeError != null) ...[
            const SizedBox(height: 8),
            Text(_routeError!, style: const TextStyle(color: Colors.orange)),
          ],

          // ETA y distancia (solo si hay ambulancia en camino)
          if (_eta != null &&
              _distance != null &&
              _currentStatus == 'ON_THE_WAY') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF652580).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF652580).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF652580),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _eta!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF652580),
                        ),
                      ),
                      Text(
                        'Tiempo estimado',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Container(height: 40, width: 1, color: Colors.grey[300]),
                  Column(
                    children: [
                      const Icon(
                        Icons.route,
                        color: Color(0xFF652580),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _distance!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF652580),
                        ),
                      ),
                      Text(
                        'Distancia',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Rutas: openrouteservice · Datos: OpenStreetMap',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ],

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
                  style: TextStyle(
                    color: _isCanceling ? Colors.grey : Colors.red,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isCanceling ? Colors.grey : Colors.red,
                  ),
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
    final s = _currentStatus.toUpperCase();
    return s == 'SEARCHING' || s == 'ASSIGNED';
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
    final steps = [
      'SEARCHING',
      'ASSIGNED',
      'ON_THE_WAY',
      'ON_SITE',
      'TRAVELLING',
      'COMPLETED',
    ];
    var currentIndex = steps.indexOf(_currentStatus);
    if (currentIndex < 0) {
      currentIndex = 0;
    }

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
                  color: isCompleted
                      ? const Color(0xFF652580)
                      : Colors.grey[300],
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
