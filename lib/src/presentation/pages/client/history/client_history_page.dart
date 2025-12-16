// lib/src/presentation/pages/client/history/client_history_page.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:intl/intl.dart';
import 'package:medcar_frontend/src/utils/date_utils.dart';
import 'package:medcar_frontend/src/utils/pdf_service.dart';

class ClientHistoryPage extends StatefulWidget {
  const ClientHistoryPage({super.key});

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final dataSource = di.sl<ServiceRequestRemoteDataSource>();
        final history = await dataSource.getMyHistory(
          token: session.accessToken,
        );
        setState(() {
          _history = history;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No hay sesión activa';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
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

  Future<void> _downloadPdf() async {
    try {
      final authRepo = di.sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session != null) {
        final userName = '${session.user.name} ${session.user.lastname}';
        await PdfService.generateServiceHistoryPdf(
          services: _history,
          title: 'Historial de Servicios',
          userName: userName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF generado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Servicios'),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
              tooltip: 'Descargar PDF',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar historial',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadHistory,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay historial de servicios',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus servicios completados y cancelados aparecerán aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final service = _history[index];
                  return _buildServiceCard(service);
                },
              ),
            ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final status = service['status'] as String? ?? '';
    final emergencyType = service['emergencyType'] as String? ?? '';
    final createdAt = service['createdAt'] as String?;
    final shift = service['shift'] as Map<String, dynamic>?;
    final ambulance = shift?['ambulance'] as Map<String, dynamic>?;
    final driver = shift?['driver'] as Map<String, dynamic>?;

    DateTime? date;
    if (createdAt != null) {
      try {
        date = parseToLocal(createdAt);
      } catch (e) {
        // Ignorar error de parsing
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
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
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
            if (ambulance != null || driver != null) ...[
              const Divider(height: 24),
              if (ambulance != null)
                _buildInfoRow(
                  Icons.local_shipping,
                  'Ambulancia: ${ambulance['plate'] ?? 'N/A'}',
                ),
              if (driver != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.person,
                  'Conductor: ${driver['name'] ?? ''} ${driver['lastname'] ?? ''}',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
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
}
