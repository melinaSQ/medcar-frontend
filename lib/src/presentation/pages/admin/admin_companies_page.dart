// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final ds = sl<AdminSystemRemoteDataSource>();
      final list = await ds.getPendingCompanies(token: session.accessToken);
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

  int? _companyId(Map<String, dynamic> c) {
    final id = c['id'] ?? c['companyId'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _companyName(Map<String, dynamic> c) {
    return (c['name'] ?? c['companyName'] ?? c['businessName'] ?? 'Empresa')
        .toString();
  }

  String _status(Map<String, dynamic> c) {
    return (c['status'] ?? 'PENDING').toString();
  }

  Future<void> _approve(int id) async {
    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) return;
    try {
      await sl<AdminSystemRemoteDataSource>().approveCompany(
        companyId: id,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empresa aprobada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _reject(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar empresa'),
        content: const Text('¿Confirmas rechazar esta solicitud?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
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
      await sl<AdminSystemRemoteDataSource>().rejectCompany(
        companyId: id,
        token: session.accessToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa rechazada')),
        );
      }
      await _load();
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
        title: const Text('Empresas pendientes'),
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
                        FilledButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No hay empresas pendientes'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          final id = _companyId(c);
                          final pending = _status(c).toUpperCase() == 'PENDING';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _companyName(c),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Estado: ${_status(c)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  if (c['email'] != null)
                                    Text('Email: ${c['email']}'),
                                  if (id != null && pending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () => _approve(id),
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
                                            onPressed: () => _reject(id),
                                            icon: const Icon(Icons.close),
                                            label: const Text('Rechazar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
