// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/admin_system_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminUserHistoryPage extends StatefulWidget {
  const AdminUserHistoryPage({
    super.key,
    required this.userId,
    required this.userLabel,
  });

  final int userId;
  final String userLabel;

  @override
  State<AdminUserHistoryPage> createState() => _AdminUserHistoryPageState();
}

class _AdminUserHistoryPageState extends State<AdminUserHistoryPage> {
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
      final list =
          await sl<AdminSystemRemoteDataSource>().getUserServiceRequestHistory(
        userId: widget.userId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial · ${widget.userLabel}'),
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
                  ? const Center(child: Text('Sin solicitudes para este usuario'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final r = _items[i];
                          final id = r['id'] ?? r['requestId'];
                          final status = (r['status'] ?? '-').toString();
                          final type =
                              (r['emergencyType'] ?? r['type'] ?? '-').toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Solicitud #$id'),
                              subtitle: Text('$type · $status'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
