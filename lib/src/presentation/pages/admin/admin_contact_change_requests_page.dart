// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminContactChangeRequestsPage extends StatefulWidget {
  const AdminContactChangeRequestsPage({super.key});

  @override
  State<AdminContactChangeRequestsPage> createState() =>
      _AdminContactChangeRequestsPageState();
}

class _AdminContactChangeRequestsPageState
    extends State<AdminContactChangeRequestsPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  final SocketService _socket = SocketService();
  StreamSubscription<void>? _adminRealtimeSub;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _listenAdminRealtime();
  }

  Future<void> _listenAdminRealtime() async {
    final session = await sl<AuthRepository>().getUserSession();
    if (!mounted || session == null) return;
    final isAdmin = session.user.roles.any((r) {
      final u = r.toUpperCase();
      return u == 'ADMIN' || u == 'SYSTEM_ADMIN';
    });
    if (!isAdmin) return;
    _socket.connect(session.accessToken);
    _adminRealtimeSub = _socket.adminQueuesUpdated.listen((_) {
      if (mounted) {
        _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _adminRealtimeSub?.cancel();
    _socket.disconnect();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await sl<AuthRepository>().getUserSession();
      if (session == null) {
        setState(() {
          _loading = false;
          _error = 'Sin sesión activa';
        });
        return;
      }

      final list =
          await sl<AdminSystemRemoteDataSource>().getPendingContactChangeRequests(
        token: session.accessToken,
        searchQuery: q,
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

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(q: v.trim().isEmpty ? null : v.trim());
    });
  }

  int? _userId(Map<String, dynamic> item) {
    final id = item['id'] ?? item['userId'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _userLabel(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final last = (item['lastname'] ?? item['lastName'] ?? '').toString();
    final full = '$name $last'.trim();
    if (full.isNotEmpty) return full;
    return (item['currentEmail'] ?? item['email'] ?? 'Usuario').toString();
  }

  Future<void> _approve(int userId) async {
    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().approveContactChange(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambio de contacto aprobado'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _reject(int userId) async {
    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().rejectContactChange(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
      }
      await _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _confirmApprove(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar cambio'),
        content: const Text(
          '¿Deseas aprobar este cambio de correo/celular?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _approve(userId);
    }
  }

  Future<void> _confirmReject(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar cambio'),
        content: const Text(
          '¿Deseas rechazar esta solicitud de cambio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _reject(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de contacto'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                _load(q: _search.text.trim().isEmpty ? null : _search.text.trim()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _loading
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
                                onPressed: () => _load(),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay solicitudes de cambio pendientes',
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(
                              q: _search.text.trim().isEmpty
                                  ? null
                                  : _search.text.trim(),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final item = _items[i];
                                final userId = _userId(item);
                                final currentEmail =
                                    (item['currentEmail'] ?? item['email'] ?? '-')
                                        .toString();
                                final currentPhone =
                                    (item['currentPhone'] ?? item['phone'] ?? '-')
                                        .toString();
                                final requestedEmail =
                                    (item['requestedEmail'] ?? item['pendingEmail'] ?? '')
                                        .toString();
                                final requestedPhone =
                                    (item['requestedPhone'] ?? item['pendingPhone'] ?? '')
                                        .toString();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userLabel(item),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Actual correo: $currentEmail'),
                                        Text('Actual celular: $currentPhone'),
                                        if (requestedEmail.isNotEmpty)
                                          Text('Solicita correo: $requestedEmail'),
                                        if (requestedPhone.isNotEmpty)
                                          Text('Solicita celular: $requestedPhone'),
                                        const SizedBox(height: 10),
                                        if (userId != null)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.icon(
                                                  onPressed: () =>
                                                      _confirmApprove(userId),
                                                  icon: const Icon(Icons.check),
                                                  label: const Text('Aprobar'),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _confirmReject(userId),
                                                  icon: const Icon(Icons.close),
                                                  label: const Text('Rechazar'),
                                                ),
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
          ),
        ],
      ),
    );
  }
}
