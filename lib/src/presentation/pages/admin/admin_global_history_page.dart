// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminGlobalHistoryPage extends StatefulWidget {
  const AdminGlobalHistoryPage({super.key});

  @override
  State<AdminGlobalHistoryPage> createState() => _AdminGlobalHistoryPageState();
}

class _AdminGlobalHistoryPageState extends State<AdminGlobalHistoryPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await sl<AuthRepository>().getUserSession();
      if (session == null) {
        setState(() {
          _error = 'Sin sesión';
          _loading = false;
        });
        return;
      }
      final list = await sl<AdminSystemRemoteDataSource>().getGlobalServiceRequests(
        token: session.accessToken,
      );
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  String _status(Map<String, dynamic> r) {
    return (r['status'] ?? '-').toString();
  }

  String _type(Map<String, dynamic> r) {
    return (r['emergencyType'] ?? r['type'] ?? '-').toString();
  }

  String? _formatDate(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return _dateFmt.format(parsed.toLocal());
      return v;
    }
    return v.toString();
  }

  String? _clientName(Map<String, dynamic> r) {
    final c = _asMap(r['client']);
    if (c == null) return null;
    final n = '${c['name'] ?? ''} ${c['lastname'] ?? ''}'.trim();
    if (n.isEmpty) return (c['email'] ?? '').toString();
    return n;
  }

  String? _clientContact(Map<String, dynamic> r) {
    final c = _asMap(r['client']);
    if (c == null) return null;
    final email = (c['email'] ?? '').toString();
    final phone = (c['phone'] ?? '').toString();
    if (email.isEmpty && phone.isEmpty) return null;
    if (phone.isEmpty) return email;
    if (email.isEmpty) return phone;
    return '$email · $phone';
  }

  String? _assignmentSummary(Map<String, dynamic> r) {
    final shift = _asMap(r['shift']);
    if (shift == null) return 'Sin ambulancia asignada';
    final amb = _asMap(shift['ambulance']);
    final driver = _asMap(shift['driver']);
    final plate = amb != null ? (amb['plate'] ?? '').toString() : '';
    final company = amb != null ? _asMap(amb['company']) : null;
    final companyName =
        company != null ? (company['name'] ?? '').toString() : '';
    final driverName = driver != null
        ? '${driver['name'] ?? ''} ${driver['lastname'] ?? ''}'.trim()
        : '';
    final parts = <String>[];
    if (companyName.isNotEmpty) parts.add(companyName);
    if (plate.isNotEmpty) parts.add('Pat. $plate');
    if (driverName.isNotEmpty) parts.add('Cond.: $driverName');
    if (parts.isEmpty) return 'Turno asignado (sin datos de unidad)';
    return parts.join(' · ');
  }

  String? _originCoords(Map<String, dynamic> r) {
    final loc = r['originLocation'];
    if (loc is Map) {
      final c = loc['coordinates'];
      if (c is List && c.length >= 2) {
        return 'Lat ${c[1]}, Lng ${c[0]}';
      }
    }
    return null;
  }

  void _openDetail(Map<String, dynamic> r) {
    final id = r['id'] ?? r['requestId'];
    final shift = _asMap(r['shift']);
    final amb = shift != null ? _asMap(shift['ambulance']) : null;
    final company = amb != null ? _asMap(amb['company']) : null;
    final driver = shift != null ? _asMap(shift['driver']) : null;
    final client = _asMap(r['client']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Solicitud #$id',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Tipo de emergencia', value: _type(r)),
              _DetailRow(label: 'Estado', value: _status(r)),
              _DetailRow(
                label: 'Creada',
                value: _formatDate(r['createdAt']),
              ),
              _DetailRow(
                label: 'Última actualización',
                value: _formatDate(r['updatedAt']),
              ),
              _DetailRow(
                label: 'Descripción origen',
                value: (r['originDescription'] ?? '').toString().trim().isEmpty
                    ? null
                    : r['originDescription'].toString(),
              ),
              _DetailRow(
                label: 'Dirección (texto)',
                value: (r['originAddressText'] ?? '').toString().trim().isEmpty
                    ? null
                    : r['originAddressText'].toString(),
              ),
              _DetailRow(label: 'Coordenadas origen', value: _originCoords(r)),
              const Divider(height: 28),
              Text(
                'Cliente',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF8B0000),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              _DetailRow(label: 'Nombre', value: _clientName(r)),
              _DetailRow(
                label: 'Correo',
                value: client != null
                    ? (client['email'] ?? '').toString().trim().isEmpty
                        ? null
                        : client['email'].toString()
                    : null,
              ),
              _DetailRow(
                label: 'Teléfono',
                value: client != null
                    ? (client['phone'] ?? '').toString().trim().isEmpty
                        ? null
                        : client['phone'].toString()
                    : null,
              ),
              const Divider(height: 28),
              Text(
                'Asignación',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF8B0000),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              if (shift == null)
                const Text('Ningún turno vinculado (solicitud sin asignar).')
              else ...[
                _DetailRow(
                  label: 'ID turno',
                  value: shift['id']?.toString(),
                ),
                _DetailRow(
                  label: 'Inicio turno',
                  value: _formatDate(shift['startTime']),
                ),
                _DetailRow(
                  label: 'Fin turno',
                  value: _formatDate(shift['endTime']),
                ),
                _DetailRow(
                  label: 'Empresa',
                  value: company != null
                      ? (company['name'] ?? '').toString().trim().isEmpty
                          ? null
                          : company['name'].toString()
                      : null,
                ),
                _DetailRow(
                  label: 'Ambulancia',
                  value: amb != null
                      ? [
                          if ((amb['plate'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            'Placa ${amb['plate']}',
                          if ((amb['sedesCode'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            'Código ${amb['sedesCode']}',
                          if ((amb['type'] ?? '').toString().trim().isNotEmpty)
                            amb['type'].toString(),
                        ].where((e) => e.isNotEmpty).join(' · ')
                      : null,
                ),
                _DetailRow(
                  label: 'Conductor',
                  value: driver != null
                      ? '${driver['name'] ?? ''} ${driver['lastname'] ?? ''}'
                          .trim()
                      : null,
                ),
                _DetailRow(
                  label: 'Tel. conductor',
                  value: driver != null
                      ? (driver['phone'] ?? '').toString().trim().isEmpty
                          ? null
                          : driver['phone'].toString()
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial global'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No hay solicitudes registradas'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final r = _items[i];
                          final id = r['id'] ?? r['requestId'];
                          final created = _formatDate(r['createdAt']);
                          final clientLine = _clientName(r);
                          final contact = _clientContact(r);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => _openDetail(r),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              Colors.red.shade50,
                                          foregroundColor:
                                              const Color(0xFF8B0000),
                                          child: const Icon(
                                            Icons.emergency,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Solicitud #$id',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (created != null)
                                                Text(
                                                  created,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${_type(r)} · ${_status(r)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (clientLine != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Cliente: $clientLine',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                    if (contact != null &&
                                        contact.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        contact,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      _assignmentSummary(r) ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Toca para ver todos los detalles',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueGrey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
