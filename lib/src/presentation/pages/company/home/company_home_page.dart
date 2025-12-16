// lib/src/presentation/pages/company/home/company_home_page.dart

// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously, unnecessary_brace_in_string_interps, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/company_admin_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/ratings_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/shifts_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'bloc/company_home_bloc.dart';
import 'bloc/company_home_event.dart';
import 'bloc/company_home_state.dart';

class CompanyHomePage extends StatelessWidget {
  const CompanyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CompanyHomeBloc(
        authRepository: sl<AuthRepository>(),
        serviceRequestDataSource: sl<ServiceRequestRemoteDataSource>(),
        shiftsDataSource: sl<ShiftsRemoteDataSource>(),
      )..add(CompanyHomeInitEvent()),
      child: const _CompanyHomeView(),
    );
  }
}

class _CompanyHomeView extends StatefulWidget {
  const _CompanyHomeView();

  @override
  State<_CompanyHomeView> createState() => _CompanyHomeViewState();
}

class _CompanyHomeViewState extends State<_CompanyHomeView> {
  final SocketService _socketService = SocketService();
  StreamSubscription? _newRequestSub;
  StreamSubscription? _statusUpdateSub;
  StreamSubscription? _requestAssignedSub;
  StreamSubscription? _locationUpdateSub;
  StreamSubscription? _requestCanceledSub;
  StreamSubscription? _ratingCreatedSub;
  Timer? _refreshTimer;
  DateTime? _lastShiftRefresh;

  int _currentTabIndex = 0;

  // Datos locales para tabs
  List<Map<String, dynamic>> _ambulances = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;
  bool _isLoadingAmbulances = false;
  bool _isLoadingDrivers = false;

  // Calificaciones
  double? _companyRating;
  int _companyRatingCount = 0;
  Map<int, double> _driverRatings = {}; // driverId -> rating
  Map<int, int> _driverRatingCounts = {}; // driverId -> count

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _startAutoRefresh();
    _loadCompanyRating();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshShifts();
      }
    });
  }

  void _refreshShifts() {
    final now = DateTime.now();
    if (_lastShiftRefresh != null &&
        now.difference(_lastShiftRefresh!).inSeconds < 3) {
      return;
    }
    _lastShiftRefresh = now;
    context.read<CompanyHomeBloc>().add(LoadActiveShiftsEvent());
  }

  Future<void> _initWebSocket() async {
    final authRepo = sl<AuthRepository>();
    final session = await authRepo.getUserSession();

    if (session != null) {
      _socketService.connect(session.accessToken);

      _newRequestSub = _socketService.onNewServiceRequest.listen((data) {
        if (mounted) {
          context.read<CompanyHomeBloc>().add(LoadPendingRequestsEvent());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 ¡Nueva solicitud de emergencia!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });

      _statusUpdateSub = _socketService.statusUpdateStream.listen((update) {
        if (mounted) {
          _refreshShifts();
          context.read<CompanyHomeBloc>().add(LoadPendingRequestsEvent());
        }
      });

      _requestAssignedSub = _socketService.requestAssignedStream.listen((
        update,
      ) {
        if (mounted) {
          _refreshShifts();
          context.read<CompanyHomeBloc>().add(LoadPendingRequestsEvent());
        }
      });

      _locationUpdateSub = _socketService.ambulanceLocationStream.listen((
        location,
      ) {
        if (mounted) {
          _refreshShifts();
        }
      });

      _requestCanceledSub = _socketService.statusUpdateStream
          .where((u) => u.status == 'CANCELED')
          .listen((update) {
            if (mounted) {
              _refreshShifts();
              context.read<CompanyHomeBloc>().add(LoadPendingRequestsEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Una solicitud fue cancelada'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });

      // Escuchar nuevas calificaciones para actualizar en tiempo real
      _ratingCreatedSub = _socketService.onRatingCreated.listen((data) {
        print('⭐ Admin: Evento rating_created recibido: $data');
        if (mounted) {
          // Recargar calificación de la empresa
          _loadCompanyRating();
          // Recargar calificaciones de conductores (siempre, no solo en la pestaña)
          if (_drivers.isNotEmpty) {
            final authRepo = sl<AuthRepository>();
            authRepo.getUserSession().then((session) {
              if (session != null && mounted) {
                print('⭐ Admin: Recargando calificaciones de conductores...');
                _loadDriverRatings(_drivers, session.accessToken);
              }
            });
          } else {
            // Si no hay conductores cargados, cargarlos primero
            _loadDrivers();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _newRequestSub?.cancel();
    _statusUpdateSub?.cancel();
    _requestAssignedSub?.cancel();
    _locationUpdateSub?.cancel();
    _requestCanceledSub?.cancel();
    _ratingCreatedSub?.cancel();
    _refreshTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }

  Future<void> _loadAmbulances() async {
    setState(() => _isLoadingAmbulances = true);
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        final ambulances = await dataSource.getMyAmbulances(
          token: session.accessToken,
        );
        setState(() => _ambulances = ambulances);
      }
    } catch (e) {
      print('Error cargando ambulancias: $e');
    } finally {
      setState(() => _isLoadingAmbulances = false);
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingDrivers = true);
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null && session.accessToken.isNotEmpty) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        final drivers = await dataSource.getDrivers(token: session.accessToken);
        setState(() => _drivers = drivers);
        // Cargar calificaciones de cada conductor
        _loadDriverRatings(drivers, session.accessToken);
      } else {
        print('⚠️ Admin: No hay sesión válida para cargar conductores');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesión expirada. Por favor, inicia sesión nuevamente.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      final errorMsg = e.toString();
      print('❌ Error cargando conductores: $e');

      // Si el error es de autenticación, mostrar mensaje al usuario
      if (errorMsg.contains('401') ||
          errorMsg.contains('Unauthorized') ||
          errorMsg.contains('token') ||
          errorMsg.contains('expirado') ||
          errorMsg.contains('invalid')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Token expirado. Por favor, inicia sesión nuevamente.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoadingDrivers = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<ServiceRequestRemoteDataSource>();
        final history = await dataSource.getCompanyHistory(
          token: session.accessToken,
        );
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('Error cargando historial: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadCompanyRating() async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null && session.accessToken.isNotEmpty) {
        final ratingsDs = sl<RatingsRemoteDataSource>();
        final result = await ratingsDs.getCompanyAverageRating(
          token: session.accessToken,
        );
        if (mounted) {
          setState(() {
            _companyRating = (result['average'] as num?)?.toDouble();
            _companyRatingCount = result['count'] ?? 0;
          });
        }
      } else {
        print(
          '⚠️ Admin: No hay sesión válida para cargar calificación de empresa',
        );
      }
    } catch (e) {
      final errorMsg = e.toString();
      print('❌ Error cargando calificación de empresa: $e');

      // Si el error es de autenticación, mostrar mensaje al usuario
      if (errorMsg.contains('401') ||
          errorMsg.contains('Unauthorized') ||
          errorMsg.contains('token') ||
          errorMsg.contains('expirado') ||
          errorMsg.contains('invalid')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Token expirado. Por favor, inicia sesión nuevamente.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadDriverRatings(
    List<Map<String, dynamic>> drivers,
    String token,
  ) async {
    print(
      '⭐ Admin: _loadDriverRatings llamado para ${drivers.length} conductores',
    );

    // Validar que el token no esté vacío
    if (token.isEmpty) {
      print('❌ Admin: Token vacío, obteniendo nueva sesión...');
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session == null || session.accessToken.isEmpty) {
        print('❌ Admin: No hay sesión válida');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesión expirada. Por favor, inicia sesión nuevamente.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      token = session.accessToken;
      print('✅ Admin: Token refrescado desde la sesión');
    }

    final ratingsDs = sl<RatingsRemoteDataSource>();

    // Cargar todas las calificaciones primero
    final Map<int, double> newRatings = {};
    final Map<int, int> newCounts = {};
    bool hasAuthError = false;

    for (final driver in drivers) {
      final driverId = driver['id'];
      if (driverId != null) {
        try {
          print('⭐ Admin: Cargando calificación para conductor $driverId');
          final result = await ratingsDs.getAverageRating(
            userId: driverId,
            token: token,
          );
          print('⭐ Admin: Resultado para conductor $driverId: $result');
          final average = (result['average'] as num?)?.toDouble();
          if (average != null && average > 0) {
            newRatings[driverId] = average;
          }
          newCounts[driverId] = result['count'] ?? 0;
          print(
            '⭐ Admin: Calificación obtenida para conductor $driverId - promedio: $average, count: ${newCounts[driverId]}',
          );
        } catch (e) {
          final errorMsg = e.toString();
          print('❌ Error cargando calificación del conductor $driverId: $e');

          // Si el error es de autenticación, intentar refrescar el token una vez
          if ((errorMsg.contains('401') ||
                  errorMsg.contains('Unauthorized') ||
                  errorMsg.contains('token') ||
                  errorMsg.contains('expirado') ||
                  errorMsg.contains('invalid')) &&
              !hasAuthError) {
            hasAuthError = true;
            print(
              '⚠️ Admin: Error de autenticación detectado, intentando refrescar sesión...',
            );
            final authRepo = sl<AuthRepository>();
            final session = await authRepo.getUserSession();
            if (session != null && session.accessToken.isNotEmpty) {
              // Actualizar el token y continuar con el siguiente conductor
              token = session.accessToken;
              print('✅ Admin: Token refrescado, continuando...');
              // Reintentar con el mismo conductor
              try {
                final result = await ratingsDs.getAverageRating(
                  userId: driverId,
                  token: token,
                );
                final average = (result['average'] as num?)?.toDouble();
                if (average != null && average > 0) {
                  newRatings[driverId] = average;
                }
                newCounts[driverId] = result['count'] ?? 0;
                print(
                  '✅ Admin: Calificación cargada después de refrescar token',
                );
              } catch (e2) {
                print('❌ Admin: Error persistente después de refrescar: $e2');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Token expirado. Por favor, inicia sesión nuevamente.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
                break; // Salir del loop si el token sigue siendo inválido
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sesión expirada. Por favor, inicia sesión nuevamente.',
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              break;
            }
          }
        }
      }
    }

    // Actualizar el estado una sola vez con todas las calificaciones
    if (mounted) {
      setState(() {
        _driverRatings = newRatings;
        _driverRatingCounts = newCounts;
        print(
          '⭐ Admin: Estado actualizado con ${newRatings.length} calificaciones',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompanyHomeBloc, CompanyHomeState>(
      listener: (context, state) {
        if (state.status == CompanyHomeStatus.assigned) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ambulancia asignada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
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
                if (_companyRating != null && _companyRating! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(width: 4),
                      Text(
                        '${_companyRating!.toStringAsFixed(1)} (${_companyRatingCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF1E3A5F),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  context.read<CompanyHomeBloc>().add(CompanyHomeInitEvent());
                  if (_currentTabIndex == 1) _loadAmbulances();
                  if (_currentTabIndex == 2) _loadDrivers();
                },
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: 'Cambiar rol',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, 'roles');
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () {
                  context.read<CompanyHomeBloc>().add(LogoutEvent());
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    'login',
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          body: state.status == CompanyHomeStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    _buildEmergenciesTab(context, state),
                    _buildAmbulancesTab(context),
                    _buildDriversTab(context),
                    _buildShiftCodesTab(context),
                    _buildHistoryTab(context),
                  ],
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentTabIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF1E3A5F),
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              setState(() => _currentTabIndex = index);
              if (index == 1 && _ambulances.isEmpty) _loadAmbulances();
              if (index == 2 && _drivers.isEmpty) _loadDrivers();
              if (index == 3 && _ambulances.isEmpty) _loadAmbulances();
              if (index == 4 && _history.isEmpty) _loadHistory();
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.emergency),
                label: 'Emergencias',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping),
                label: 'Ambulancias',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Conductores',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code),
                label: 'Códigos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB EMERGENCIAS ====================
  Widget _buildEmergenciesTab(BuildContext context, CompanyHomeState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<CompanyHomeBloc>().add(CompanyHomeInitEvent());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              '🚨 Solicitudes Pendientes',
              state.pendingRequests.length,
            ),
            const SizedBox(height: 12),
            if (state.pendingRequests.isEmpty)
              _buildEmptyCard('No hay solicitudes pendientes')
            else
              ...state.pendingRequests.map(
                (request) => _buildRequestCard(
                  context,
                  request,
                  state.activeShifts,
                  state.status == CompanyHomeStatus.assigning,
                ),
              ),
            const SizedBox(height: 24),
            _buildSectionTitle('🚑 Turnos Activos', state.activeShifts.length),
            const SizedBox(height: 12),
            if (state.activeShifts.isEmpty)
              _buildEmptyCard('No hay turnos activos')
            else
              ...state.activeShifts.map((shift) => _buildShiftCard(shift)),
          ],
        ),
      ),
    );
  }

  // ==================== TAB AMBULANCIAS ====================
  Widget _buildAmbulancesTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🚑 Mis Ambulancias',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateAmbulanceDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingAmbulances
              ? const Center(child: CircularProgressIndicator())
              : _ambulances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes ambulancias registradas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showCreateAmbulanceDialog(context),
                        child: const Text('Registrar primera ambulancia'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAmbulances,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ambulances.length,
                    itemBuilder: (context, index) =>
                        _buildAmbulanceCard(_ambulances[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAmbulanceCard(Map<String, dynamic> ambulance) {
    final status = ambulance['status'] ?? 'OPERATIONAL';
    final ambulanceId = ambulance['id'];

    String _getStatusText(String status) {
      switch (status) {
        case 'OPERATIONAL':
          return 'OPERATIVA';
        case 'IN_MAINTENANCE':
          return 'EN MANTENIMIENTO';
        case 'OUT_OF_SERVICE':
          return 'FUERA DE SERVICIO';
        default:
          return status;
      }
    }

    Color _getStatusColor(String status) {
      switch (status) {
        case 'OPERATIONAL':
          return Colors.green;
        case 'IN_MAINTENANCE':
          return Colors.orange;
        case 'OUT_OF_SERVICE':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  child: Icon(
                    Icons.local_shipping,
                    color: _getStatusColor(status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ambulance['plate'] ?? 'Sin placa',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tipo: ${ambulance['type'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        'SEDES: ${ambulance['sedesCode'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () =>
                      _showChangeStatusDialog(context, ambulanceId, status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showEditAmbulanceDialog(context, ambulance),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _showDeleteAmbulanceDialog(context, ambulanceId),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAmbulanceDialog(BuildContext context) {
    final plateController = TextEditingController();
    final sedesController = TextEditingController();
    String selectedType = 'TYPE_I';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Ambulancia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa',
                    hintText: 'Ej: 1234ABC',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sedesController,
                  decoration: const InputDecoration(
                    labelText: 'Código SEDES',
                    hintText: 'Ej: SEDES-001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de ambulancia',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TYPE_I',
                      child: Text('Tipo I - Traslado'),
                    ),
                    DropdownMenuItem(
                      value: 'TYPE_II',
                      child: Text('Tipo II - Emergencias básicas'),
                    ),
                    DropdownMenuItem(
                      value: 'TYPE_III',
                      child: Text('Tipo III - UCI Móvil'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (plateController.text.isEmpty ||
                    sedesController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _createAmbulance(
                  plateController.text,
                  sedesController.text,
                  selectedType,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
              ),
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAmbulance(
    String plate,
    String sedesCode,
    String type,
  ) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        await dataSource.createAmbulance(
          plate: plate,
          sedesCode: sedesCode,
          type: type,
          token: session.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ambulancia creada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAmbulances();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditAmbulanceDialog(
    BuildContext context,
    Map<String, dynamic> ambulance,
  ) {
    final plateController = TextEditingController(
      text: ambulance['plate'] ?? '',
    );
    final sedesController = TextEditingController(
      text: ambulance['sedesCode'] ?? '',
    );
    String selectedType = ambulance['type'] ?? 'TYPE_I';
    final ambulanceId = ambulance['id'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Ambulancia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa',
                    hintText: 'Ej: 1234ABC',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sedesController,
                  decoration: const InputDecoration(
                    labelText: 'Código SEDES',
                    hintText: 'Ej: SEDES-001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de ambulancia',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TYPE_I',
                      child: Text('Tipo I - Traslado'),
                    ),
                    DropdownMenuItem(
                      value: 'TYPE_II',
                      child: Text('Tipo II - Emergencias básicas'),
                    ),
                    DropdownMenuItem(
                      value: 'TYPE_III',
                      child: Text('Tipo III - UCI Móvil'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (plateController.text.isEmpty ||
                    sedesController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _updateAmbulance(
                  ambulanceId,
                  plateController.text,
                  sedesController.text,
                  selectedType,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAmbulance(
    int ambulanceId,
    String plate,
    String sedesCode,
    String type,
  ) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        await dataSource.updateAmbulance(
          ambulanceId: ambulanceId,
          plate: plate,
          sedesCode: sedesCode,
          type: type,
          token: session.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ambulancia actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAmbulances();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteAmbulanceDialog(BuildContext context, int? ambulanceId) {
    if (ambulanceId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Ambulancia'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta ambulancia?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteAmbulance(ambulanceId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAmbulance(int ambulanceId) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        await dataSource.deleteAmbulance(
          ambulanceId: ambulanceId,
          token: session.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ambulancia eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAmbulances();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangeStatusDialog(
    BuildContext context,
    int? ambulanceId,
    String currentStatus,
  ) {
    if (ambulanceId == null) return;

    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar Estado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Operativa'),
                subtitle: const Text('Lista para usar'),
                value: 'OPERATIONAL',
                groupValue: selectedStatus,
                activeColor: Colors.green,
                onChanged: (value) {
                  setDialogState(() => selectedStatus = value!);
                },
              ),
              RadioListTile<String>(
                title: const Text('En Mantenimiento'),
                subtitle: const Text('En el taller'),
                value: 'IN_MAINTENANCE',
                groupValue: selectedStatus,
                activeColor: Colors.orange,
                onChanged: (value) {
                  setDialogState(() => selectedStatus = value!);
                },
              ),
              RadioListTile<String>(
                title: const Text('Fuera de Servicio'),
                subtitle: const Text('Retirada temporal o permanentemente'),
                value: 'OUT_OF_SERVICE',
                groupValue: selectedStatus,
                activeColor: Colors.red,
                onChanged: (value) {
                  setDialogState(() => selectedStatus = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _updateAmbulanceStatus(ambulanceId, selectedStatus);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAmbulanceStatus(int ambulanceId, String status) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        await dataSource.updateAmbulanceStatus(
          ambulanceId: ambulanceId,
          status: status,
          token: session.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estado actualizado'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAmbulances();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== TAB CONDUCTORES ====================
  Widget _buildDriversTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '👨‍✈️ Conductores',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignDriverDialog(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Asignar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingDrivers
              ? const Center(child: CircularProgressIndicator())
              : _drivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay conductores asignados',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showAssignDriverDialog(context),
                        child: const Text('Asignar primer conductor'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrivers,
                  child: ListView.builder(
                    key: ValueKey(
                      'drivers_list_${_driverRatings.length}_${_driverRatings.values.fold(0.0, (sum, rating) => sum + rating)}',
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _drivers.length,
                    itemBuilder: (context, index) =>
                        _buildDriverCard(_drivers[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDriverRating(int? driverId) {
    if (driverId == null) return const SizedBox.shrink();

    final rating = _driverRatings[driverId];
    final count = _driverRatingCounts[driverId] ?? 0;

    if (rating != null && rating > 0 && count > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (index) {
            return Icon(
              index < rating.round() ? Icons.star : Icons.star_border,
              size: 14,
              color: Colors.amber,
            );
          }),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      );
    } else {
      return Text(
        'Sin calificaciones aún',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final driverId = driver['id'];
    final rating = driverId != null ? _driverRatings[driverId] : null;
    final count = driverId != null ? _driverRatingCounts[driverId] ?? 0 : 0;
    // Key único basado en el ID y la calificación para forzar reconstrucción
    final cardKey = ValueKey('driver_${driverId}_${rating}_$count');

    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            '${driver['name']?[0] ?? ''}${driver['lastname']?[0] ?? ''}'
                .toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(
          '${driver['name'] ?? ''} ${driver['lastname'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driver['email'] ?? 'Sin email'),
            Text('📱 ${driver['phone'] ?? 'Sin teléfono'}'),
            const SizedBox(height: 4),
            _buildDriverRating(driver['id']),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove, color: Colors.red),
          tooltip: 'Quitar rol de conductor',
          onPressed: () => _showRemoveDriverDialog(driver),
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showRemoveDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar Conductor'),
        content: Text(
          '¿Estás seguro de quitar el rol de conductor a ${driver['name']} ${driver['lastname']}?\n\nEl usuario ya no podrá iniciar turnos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _removeDriverRole(driver['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Quitar rol',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeDriverRole(int userId) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        await dataSource.removeDriverRole(
          userId: userId,
          token: session.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Rol de conductor removido'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDrivers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAssignDriverDialog(BuildContext context) {
    final emailController = TextEditingController();
    Map<String, dynamic>? foundUser;
    bool isSearching = false;
    bool isAssigning = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Asignar Conductor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Busca un usuario por email para asignarle el rol de conductor.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email del usuario',
                          hintText: 'ejemplo@email.com',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isSearching
                          ? null
                          : () async {
                              if (emailController.text.isEmpty) return;
                              setDialogState(() {
                                isSearching = true;
                                foundUser = null;
                              });
                              try {
                                final authRepo = sl<AuthRepository>();
                                final session = await authRepo.getUserSession();
                                if (session != null) {
                                  final dataSource =
                                      sl<CompanyAdminRemoteDataSource>();
                                  final user = await dataSource
                                      .searchUserByEmail(
                                        email: emailController.text,
                                        token: session.accessToken,
                                      );
                                  setDialogState(() => foundUser = user);
                                }
                              } catch (e) {
                                print('Error buscando usuario: $e');
                              } finally {
                                setDialogState(() => isSearching = false);
                              }
                            },
                      icon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (foundUser != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${foundUser!['name']} ${foundUser!['lastname']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Email: ${foundUser!['email']}'),
                        Text('Teléfono: ${foundUser!['phone']}'),
                        const SizedBox(height: 8),
                        if ((foundUser!['roles'] as List?)?.contains(
                              'DRIVER',
                            ) ==
                            true)
                          const Text(
                            '⚠️ Este usuario ya es conductor',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: isAssigning
                                ? null
                                : () async {
                                    setDialogState(() => isAssigning = true);
                                    try {
                                      final authRepo = sl<AuthRepository>();
                                      final session = await authRepo
                                          .getUserSession();
                                      if (session != null) {
                                        final dataSource =
                                            sl<CompanyAdminRemoteDataSource>();
                                        await dataSource.assignDriverRole(
                                          userId: foundUser!['id'],
                                          token: session.accessToken,
                                        );
                                        Navigator.pop(dialogContext);
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✅ Conductor asignado',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadDrivers();
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error: ${e.toString().replaceAll('Exception: ', '')}',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      setDialogState(() => isAssigning = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: isAssigning
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Asignar como conductor',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                      ],
                    ),
                  )
                else if (emailController.text.isNotEmpty && !isSearching)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Usuario no encontrado'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB CÓDIGOS DE TURNO ====================
  Widget _buildShiftCodesTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔑 Generar Código de Turno',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona una ambulancia para generar un código que el conductor usará para iniciar su turno.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingAmbulances
                ? const Center(child: CircularProgressIndicator())
                : _ambulances.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Primero registra una ambulancia',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _ambulances.length,
                    itemBuilder: (context, index) {
                      final ambulance = _ambulances[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF1E3A5F),
                            child: Icon(
                              Icons.local_shipping,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            ambulance['plate'] ?? 'Sin placa',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Tipo: ${ambulance['type'] ?? 'N/A'}'),
                          trailing: ElevatedButton(
                            onPressed: () =>
                                _generateShiftCode(ambulance['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text(
                              'Generar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB HISTORIAL ====================
  Widget _buildHistoryTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📋 Historial de Servicios',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadHistory,
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay historial de servicios',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los servicios completados y cancelados aparecerán aquí',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    child: ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final service = _history[index];
                        return _buildHistoryCard(service);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> service) {
    final status = service['status'] as String? ?? '';
    final emergencyType = service['emergencyType'] as String? ?? '';
    final createdAt = service['createdAt'] as String?;
    final client = service['client'] as Map<String, dynamic>?;
    final shift = service['shift'] as Map<String, dynamic>?;
    final ambulance = shift?['ambulance'] as Map<String, dynamic>?;
    final driver = shift?['driver'] as Map<String, dynamic>?;

    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt);
      } catch (e) {
        // Ignorar error de parsing
      }
    }

    String _getEmergencyTypeText(String type) {
      switch (type) {
        case 'TRAFFIC_ACCIDENT':
          return 'Accidente de tránsito';
        case 'MEDICAL_EMERGENCY':
          return 'Emergencia médica';
        case 'FIRE':
          return 'Incendio';
        case 'OTHER':
          return 'Otro';
        default:
          return type;
      }
    }

    String _getStatusText(String status) {
      switch (status) {
        case 'COMPLETED':
          return 'Completado';
        case 'CANCELED':
          return 'Cancelado';
        default:
          return status;
      }
    }

    Color _getStatusColor(String status) {
      switch (status) {
        case 'COMPLETED':
          return Colors.green;
        case 'CANCELED':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getEmergencyTypeText(emergencyType),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (client != null || ambulance != null || driver != null) ...[
              const Divider(height: 24),
              if (client != null)
                _buildHistoryInfoRow(
                  Icons.person,
                  'Cliente: ${client['name'] ?? ''} ${client['lastname'] ?? ''}',
                ),
              if (ambulance != null) ...[
                const SizedBox(height: 8),
                _buildHistoryInfoRow(
                  Icons.local_shipping,
                  'Ambulancia: ${ambulance['plate'] ?? 'N/A'}',
                ),
              ],
              if (driver != null) ...[
                const SizedBox(height: 8),
                _buildHistoryInfoRow(
                  Icons.person_outline,
                  'Conductor: ${driver['name'] ?? ''} ${driver['lastname'] ?? ''}',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Future<void> _generateShiftCode(int ambulanceId) async {
    try {
      final authRepo = sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = sl<CompanyAdminRemoteDataSource>();
        final result = await dataSource.generateShiftCode(
          ambulanceId: ambulanceId,
          token: session.accessToken,
        );

        final code = result['code'] ?? 'N/A';
        final expiresAt = result['expiresAt'] ?? 'N/A';

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Código Generado'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Comparte este código con el conductor:'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código copiado'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '⏰ Expira: ${_formatDate(expiresAt)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  // ==================== WIDGETS COMPARTIDOS ====================
  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.red : Colors.grey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: TextStyle(color: Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    Map<String, dynamic> request,
    List<Map<String, dynamic>> activeShifts,
    bool isAssigning,
  ) {
    final emergencyType = request['emergencyType'] ?? 'N/A';
    final client = request['client'] as Map<String, dynamic>?;
    final clientName = client != null
        ? '${client['name']} ${client['lastname']}'
        : 'Cliente';
    final createdAt = request['createdAt'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    emergencyType,
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  clientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (activeShifts.isEmpty)
              const Text(
                '⚠️ No hay ambulancias disponibles',
                style: TextStyle(color: Colors.orange),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isAssigning
                      ? null
                      : () => _showAssignAmbulanceDialog(
                          context,
                          request,
                          activeShifts,
                        ),
                  icon: isAssigning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_shipping, size: 18),
                  label: Text(
                    isAssigning ? 'Asignando...' : 'Asignar Ambulancia',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAssignAmbulanceDialog(
    BuildContext context,
    Map<String, dynamic> request,
    List<Map<String, dynamic>> activeShifts,
  ) {
    final availableShifts = activeShifts
        .where((s) => s['hasActiveEmergency'] != true)
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seleccionar Ambulancia'),
        content: SizedBox(
          width: double.maxFinite,
          child: availableShifts.isEmpty
              ? const Text('No hay ambulancias disponibles')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableShifts.length,
                  itemBuilder: (context, index) {
                    final shift = availableShifts[index];
                    final ambulance =
                        shift['ambulance'] as Map<String, dynamic>?;
                    final driver = shift['driver'] as Map<String, dynamic>?;

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1E3A5F),
                        child: Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(ambulance?['plate'] ?? 'Sin placa'),
                      subtitle: Text(
                        'Conductor: ${driver?['name'] ?? 'N/A'} ${driver?['lastname'] ?? ''}',
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        this.context.read<CompanyHomeBloc>().add(
                          AssignRequestEvent(
                            requestId: request['id'],
                            shiftId: shift['id'],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final ambulance = shift['ambulance'] as Map<String, dynamic>?;
    final driver = shift['driver'] as Map<String, dynamic>?;
    final hasEmergency = shift['hasActiveEmergency'] == true;
    final emergencyStatus = shift['emergencyStatus'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasEmergency
              ? Colors.orange[100]
              : Colors.green[100],
          child: Icon(
            Icons.local_shipping,
            color: hasEmergency ? Colors.orange : Colors.green,
          ),
        ),
        title: Text(
          ambulance?['plate'] ?? 'Sin placa',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${ambulance?['type'] ?? 'N/A'}'),
            Text(
              'Conductor: ${driver?['name'] ?? 'N/A'} ${driver?['lastname'] ?? ''}',
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasEmergency ? Colors.orange : Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            hasEmergency ? (emergencyStatus ?? 'EN SERVICIO') : 'DISPONIBLE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
