// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
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

  void _showUserActions(Map<String, dynamic> user) {
    final id = _userId(user);
    if (id == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
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
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(_userLabel(u)),
                                    subtitle: Text(
                                      (u['email'] ?? '').toString(),
                                    ),
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
