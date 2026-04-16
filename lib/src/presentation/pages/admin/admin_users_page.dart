// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _search = TextEditingController();
  final SocketService _socket = SocketService();
  StreamSubscription<void>? _adminRealtimeSub;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _adminRealtimeSub?.cancel();
    _socket.disconnect();
    _search.dispose();
    super.dispose();
  }

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

  Future<void> _load({String? q}) async {
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
      final list = await sl<AdminSystemRemoteDataSource>().getAllUsers(
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

  int? _userId(Map<String, dynamic> u) {
    final id = u['id'] ?? u['userId'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _userLabel(Map<String, dynamic> u) {
    final name = u['name'] ?? '';
    final last = u['lastname'] ?? u['lastName'] ?? '';
    final email = u['email'] ?? '';
    final full = '$name $last'.trim();
    if (full.isNotEmpty) return full;
    return email.toString();
  }

  bool _hasPendingContactChange(Map<String, dynamic> u) {
    final pendingEmail =
        (u['pendingEmail'] ?? u['requestedEmail'] ?? '').toString().trim();
    final pendingPhone =
        (u['pendingPhone'] ?? u['requestedPhone'] ?? '').toString().trim();
    return pendingEmail.isNotEmpty || pendingPhone.isNotEmpty;
  }

  bool _isUserBlocked(Map<String, dynamic> u) {
    final v = u['isBlocked'] ?? u['is_blocked'];
    if (v is bool) return v;
    if (v is String) {
      return v.toLowerCase() == 'true' || v == '1';
    }
    if (v is num) return v != 0;
    return false;
  }

  void _showUserActions(Map<String, dynamic> user) {
    final id = _userId(user);
    if (id == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasPendingContactChange(user))
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Colors.green),
                  title: const Text('Aprobar cambio de contacto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmApproveContactChange(id);
                  },
                ),
              if (_hasPendingContactChange(user))
                ListTile(
                  leading:
                      const Icon(Icons.cancel_outlined, color: Colors.orange),
                  title: const Text('Rechazar cambio de contacto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmRejectContactChange(id);
                  },
                ),
              if (_isUserBlocked(user)) ...[
                const ListTile(
                  leading: Icon(Icons.block, color: Colors.grey),
                  title: Text('Usuario bloqueado'),
                  subtitle: Text(
                    'La cuenta no puede iniciar sesión ni usar la API hasta restaurar el acceso.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_open, color: Colors.green),
                  title: const Text('Desbloquear usuario'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmUnblock(id);
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Bloquear usuario'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmBlock(id);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar usuario'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ver historial de solicitudes'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    'admin/user-history',
                    arguments: {'userId': id, 'label': _userLabel(user)},
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlock(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: const Text('¿Bloquear esta cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().blockUser(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario bloqueado')),
        );
      }
      await _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmUnblock(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desbloquear usuario'),
        content: const Text(
          '¿Restaurar el acceso a esta cuenta? Podrá iniciar sesión de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().unblockUser(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario desbloqueado'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmDelete(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
          'Esta acción puede ser irreversible. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().deleteUser(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
      }
      await _load(q: _search.text.trim().isEmpty ? null : _search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmApproveContactChange(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar cambio'),
        content: const Text(
          '¿Aprobar la solicitud de cambio de correo/celular de este usuario?',
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
    if (ok != true) return;

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

  Future<void> _confirmRejectContactChange(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar cambio'),
        content: const Text(
          '¿Rechazar la solicitud de cambio de correo/celular de este usuario?',
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
    if (ok != true) return;

    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().rejectContactChange(
        userId: userId,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de cambio rechazada')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user),
            tooltip: 'Solicitudes de contacto',
            onPressed: () =>
                Navigator.pushNamed(context, 'admin/contact-change-requests'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(
              q: _search.text.trim().isEmpty ? null : _search.text.trim(),
            ),
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
                hintText: 'Buscar por nombre o email…',
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
                        ? const Center(child: Text('No hay usuarios'))
                        : RefreshIndicator(
                            onRefresh: () => _load(
                              q: _search.text.trim().isEmpty
                                  ? null
                                  : _search.text.trim(),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final u = _items[i];
                                final hasPendingChange = _hasPendingContactChange(
                                  u,
                                );
                                final blocked = _isUserBlocked(u);
                                final requestedEmail =
                                    (u['pendingEmail'] ?? u['requestedEmail'] ?? '')
                                        .toString();
                                final requestedPhone =
                                    (u['pendingPhone'] ?? u['requestedPhone'] ?? '')
                                        .toString();
                                final emailLine =
                                    (u['email'] ?? '').toString();
                                String subtitleText = emailLine;
                                if (blocked) {
                                  subtitleText =
                                      '$emailLine\nCuenta bloqueada';
                                } else if (hasPendingChange) {
                                  subtitleText =
                                      '$emailLine\n'
                                      'Pendiente: '
                                      '${requestedEmail.isNotEmpty ? 'correo ' : ''}'
                                      '${requestedPhone.isNotEmpty ? 'celular' : ''}';
                                }
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: blocked
                                      ? Colors.grey.shade200
                                      : null,
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(_userLabel(u))),
                                        if (blocked)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Chip(
                                              label: const Text(
                                                'Bloqueado',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.grey.shade800,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(subtitleText),
                                    isThreeLine:
                                        hasPendingChange || blocked,
                                    trailing: const Icon(Icons.more_vert),
                                    onTap: () => _showUserActions(u),
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
