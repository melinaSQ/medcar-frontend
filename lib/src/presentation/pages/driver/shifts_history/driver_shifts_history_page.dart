// lib/src/presentation/pages/driver/shifts_history/driver_shifts_history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/src/data/datasources/remote/shifts_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class DriverShiftsHistoryPage extends StatefulWidget {
  const DriverShiftsHistoryPage({super.key});

  @override
  State<DriverShiftsHistoryPage> createState() =>
      _DriverShiftsHistoryPageState();
}

class _DriverShiftsHistoryPageState extends State<DriverShiftsHistoryPage> {
  List<Map<String, dynamic>> _shifts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = di.sl<ShiftsRemoteDataSource>();
        final shifts = await dataSource.getDriverShiftHistory(
          token: session.accessToken,
        );
        setState(() {
          _shifts = shifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _calculateDuration(DateTime? startTime, DateTime? endTime) {
    if (startTime == null || endTime == null) return 'N/A';
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  int _getServiceCount(Map<String, dynamic> shift) {
    final serviceRequests = shift['serviceRequests'] as List<dynamic>?;
    return serviceRequests?.length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Turnos'),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar historial',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadShifts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : _shifts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay turnos en el historial',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los turnos finalizados aparecerán aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadShifts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _shifts.length,
                itemBuilder: (context, index) {
                  final shift = _shifts[index];
                  final ambulance = shift['ambulance'] as Map<String, dynamic>?;
                  final startTime = shift['startTime'] != null
                      ? DateTime.parse(shift['startTime'])
                      : null;
                  final endTime = shift['endTime'] != null
                      ? DateTime.parse(shift['endTime'])
                      : null;
                  final serviceCount = _getServiceCount(shift);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2E7D32,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Color(0xFF2E7D32),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Turno #${shift['id']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (ambulance != null)
                                      Text(
                                        'Ambulancia: ${ambulance['plate'] ?? 'N/A'}',
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
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoItem(
                                Icons.play_arrow,
                                'Inicio',
                                _formatDate(startTime),
                              ),
                              _buildInfoItem(
                                Icons.stop,
                                'Fin',
                                _formatDate(endTime),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoItem(
                                Icons.access_time,
                                'Duración',
                                _calculateDuration(startTime, endTime),
                              ),
                              _buildInfoItem(
                                Icons.emergency,
                                'Servicios',
                                '$serviceCount',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
