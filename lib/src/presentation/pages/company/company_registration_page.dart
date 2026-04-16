// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/company_admin_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

/// Registro de empresa para obtener el rol COMPANY_ADMIN tras aprobación del administrador del sistema.
class CompanyRegistrationPage extends StatefulWidget {
  const CompanyRegistrationPage({super.key, this.existingCompany});

  /// Si existe (p. ej. rechazada), se pueden precargar datos.
  final Map<String, dynamic>? existingCompany;

  @override
  State<CompanyRegistrationPage> createState() =>
      _CompanyRegistrationPageState();
}

class _CompanyRegistrationPageState extends State<CompanyRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.existingCompany;
    final ex = widget.existingCompany;
    if (ex != null) {
      _nameCtrl.text = (ex['name'] ?? '').toString();
      _rucCtrl.text = (ex['ruc'] ?? '').toString();
      _phoneCtrl.text = (ex['phone'] ?? '').toString();
    }
    _reloadFromServer();
  }

  Future<void> _reloadFromServer() async {
    final session = await sl<AuthRepository>().getUserSession();
    if (!mounted || session == null) return;
    try {
      final c = await sl<CompanyAdminRemoteDataSource>().getMyCompany(
        token: session.accessToken,
      );
      if (mounted && c != null) {
        setState(() {
          _current = c;
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = (c['name'] ?? '').toString();
          }
          if (_rucCtrl.text.isEmpty) {
            _rucCtrl.text = (c['ruc'] ?? '').toString();
          }
          if (_phoneCtrl.text.isEmpty) {
            _phoneCtrl.text = (c['phone'] ?? '').toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rucCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _statusLabel(String? s) {
    switch (s?.toUpperCase()) {
      case 'PENDING':
        return 'En revisión por el administrador';
      case 'APPROVED':
        return 'Aprobada';
      case 'REJECTED':
        return 'Rechazada — puedes corregir y volver a enviar';
      default:
        return s ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = await sl<AuthRepository>().getUserSession();
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión no válida')),
        );
      }
      return;
    }

    final status = _current?['status']?.toString().toUpperCase();
    if (status == 'PENDING') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes una solicitud en revisión.'),
          ),
        );
      }
      return;
    }
    if (status == 'APPROVED') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu empresa ya está aprobada. Actualiza sesión desde el menú principal.'),
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await sl<CompanyAdminRemoteDataSource>().registerCompany(
        name: _nameCtrl.text.trim(),
        ruc: _rucCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        token: session.accessToken,
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Solicitud enviada'),
            content: const Text(
              'Tu solicitud de registro de empresa quedó registrada. '
              'Cuando un administrador del sistema la apruebe, podrás usar el rol «Admin de Empresa». '
              'Vuelve a iniciar sesión o actualiza desde el menú de roles si ya te aprobaron.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _current?['status']?.toString();
    final blocked = status?.toUpperCase() == 'PENDING' ||
        status?.toUpperCase() == 'APPROVED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar empresa'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_current != null) ...[
                Material(
                  color: status?.toUpperCase() == 'PENDING'
                      ? Colors.orange.shade50
                      : status?.toUpperCase() == 'REJECTED'
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          status?.toUpperCase() == 'PENDING'
                              ? Icons.hourglass_top
                              : status?.toUpperCase() == 'REJECTED'
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                          color: status?.toUpperCase() == 'PENDING'
                              ? Colors.orange.shade800
                              : status?.toUpperCase() == 'REJECTED'
                                  ? Colors.red.shade800
                                  : Colors.green.shade800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusLabel(status),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Completa los datos de tu empresa o cooperativa. Un administrador del sistema validará la solicitud antes de asignarte el rol de administrador de empresa.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                enabled: !blocked,
                decoration: InputDecoration(
                  labelText: 'Nombre de la empresa',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.business),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rucCtrl,
                enabled: !blocked,
                decoration: InputDecoration(
                  labelText: 'RUC / NIT (10–13 caracteres)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.text,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  final len = v.trim().length;
                  if (len < 10 || len > 13) {
                    return 'Entre 10 y 13 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                enabled: !blocked,
                decoration: InputDecoration(
                  labelText: 'Teléfono de la empresa',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  if (v.trim().length < 7) {
                    return 'Teléfono demasiado corto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              if (!blocked)
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar solicitud'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
