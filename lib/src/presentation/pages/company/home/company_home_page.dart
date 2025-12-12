// lib/src/presentation/pages/company/home/company_home_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/dependency_injection.dart';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Refrescar turnos activos cada 15 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        context.read<CompanyHomeBloc>().add(LoadActiveShiftsEvent());
      }
    });
  }

  Future<void> _initWebSocket() async {
    final authRepo = sl<AuthRepository>();
    final session = await authRepo.getUserSession();
    
    if (session != null) {
      _socketService.connect(session.accessToken);
      
      // Escuchar nuevas solicitudes
      _newRequestSub = _socketService.onNewServiceRequest.listen((data) {
        if (mounted) {
          // Recargar solicitudes pendientes
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

      // Escuchar actualizaciones de estado (cuando conductor cambia estado)
      _statusUpdateSub = _socketService.statusUpdateStream.listen((update) {
        if (mounted) {
          // Recargar turnos activos para ver el nuevo estado
          context.read<CompanyHomeBloc>().add(LoadActiveShiftsEvent());
        }
      });
    }
  }

  @override
  void dispose() {
    _newRequestSub?.cancel();
    _statusUpdateSub?.cancel();
    _refreshTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
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
            title: Text(
              'Hola, ${state.userName}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1E3A5F),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  context.read<CompanyHomeBloc>().add(CompanyHomeInitEvent());
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
                  Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
                },
              ),
            ],
          ),
          body: state.status == CompanyHomeStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    context.read<CompanyHomeBloc>().add(CompanyHomeInitEvent());
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección de solicitudes pendientes
                        _buildSectionTitle(
                          '🚨 Solicitudes Pendientes',
                          state.pendingRequests.length,
                        ),
                        const SizedBox(height: 12),
                        if (state.pendingRequests.isEmpty)
                          _buildEmptyCard('No hay solicitudes pendientes')
                        else
                          ...state.pendingRequests.map((request) => _buildRequestCard(
                            context,
                            request,
                            state.activeShifts,
                            state.status == CompanyHomeStatus.assigning,
                          )),

                        const SizedBox(height: 24),

                        // Sección de turnos activos
                        _buildSectionTitle(
                          '🚑 Turnos Activos',
                          state.activeShifts.length,
                        ),
                        const SizedBox(height: 12),
                        if (state.activeShifts.isEmpty)
                          _buildEmptyCard('No hay turnos activos')
                        else
                          ...state.activeShifts.map((shift) => _buildShiftCard(shift)),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.red : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
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
    final client = request['client'] as Map<String, dynamic>?;
    final clientName = client != null ? '${client['name']} ${client['lastname']}' : 'Desconocido';
    final emergencyType = request['emergencyType'] ?? 'N/A';
    final description = request['originDescription'] ?? 'Sin descripción';
    final location = request['originLocation'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as List<dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getEmergencyColor(emergencyType),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emergencyType,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  '#${request['id']}',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (client?['phone'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(client!['phone'], style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            if (coordinates != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Lat: ${coordinates[1].toStringAsFixed(4)}, Lng: ${coordinates[0].toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Asignar a:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (activeShifts.isEmpty)
              Text(
                'No hay turnos activos disponibles',
                style: TextStyle(color: Colors.red[400], fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeShifts.map((shift) {
                  final ambulance = shift['ambulance'] as Map<String, dynamic>?;
                  final driver = shift['driver'] as Map<String, dynamic>?;
                  final plate = ambulance?['plate'] ?? 'N/A';
                  final driverName = driver?['name'] ?? 'Sin conductor';

                  return ElevatedButton.icon(
                    onPressed: isAssigning
                        ? null
                        : () {
                            _showAssignConfirmation(
                              context,
                              request['id'],
                              shift['id'],
                              plate,
                              driverName,
                            );
                          },
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: Text('$plate ($driverName)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final ambulance = shift['ambulance'] as Map<String, dynamic>?;
    final driver = shift['driver'] as Map<String, dynamic>?;
    final plate = ambulance?['plate'] ?? 'N/A';
    final type = ambulance?['type'] ?? 'N/A';
    final driverName = driver != null ? '${driver['name']} ${driver['lastname']}' : 'Sin conductor';
    final hasActiveEmergency = shift['hasActiveEmergency'] == true;
    final emergencyStatus = shift['emergencyStatus'] as String?;

    // Determinar color y texto según el estado
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (hasActiveEmergency) {
      switch (emergencyStatus) {
        case 'ASSIGNED':
          statusColor = Colors.blue;
          statusText = 'ASIGNADO';
          statusIcon = Icons.assignment;
          break;
        case 'ON_THE_WAY':
          statusColor = Colors.orange;
          statusText = 'EN CAMINO';
          statusIcon = Icons.directions_car;
          break;
        case 'ON_SITE':
          statusColor = Colors.purple;
          statusText = 'EN LUGAR';
          statusIcon = Icons.location_on;
          break;
        case 'TRAVELLING':
          statusColor = Colors.red;
          statusText = 'TRASLADO';
          statusIcon = Icons.local_hospital;
          break;
        default:
          statusColor = Colors.red;
          statusText = 'EN SERVICIO';
          statusIcon = Icons.emergency;
      }
    } else {
      statusColor = Colors.green;
      statusText = 'DISPONIBLE';
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasActiveEmergency ? statusColor : const Color(0xFF1E3A5F),
          child: Icon(hasActiveEmergency ? statusIcon : Icons.local_shipping, color: Colors.white),
        ),
        title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: $type'),
            Text('Conductor: $driverName'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Color _getEmergencyColor(String type) {
    switch (type.toUpperCase()) {
      case 'ACCIDENTE':
        return Colors.red;
      case 'CARDIACO':
        return Colors.purple;
      case 'RESPIRATORIO':
        return Colors.blue;
      case 'TRAUMA':
        return Colors.orange;
      case 'PEDIATRICO':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  void _showAssignConfirmation(
    BuildContext context,
    int requestId,
    int shiftId,
    String plate,
    String driverName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Asignación'),
        content: Text(
          '¿Asignar la ambulancia $plate ($driverName) a esta emergencia?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CompanyHomeBloc>().add(
                AssignRequestEvent(requestId: requestId, shiftId: shiftId),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Asignar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

