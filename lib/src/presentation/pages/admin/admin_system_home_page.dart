// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class AdminSystemHomePage extends StatefulWidget {
  const AdminSystemHomePage({super.key});

  @override
  State<AdminSystemHomePage> createState() => _AdminSystemHomePageState();
}

class _AdminSystemHomePageState extends State<AdminSystemHomePage> {
  String _welcomeName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final session = await sl<AuthRepository>().getUserSession();
    if (!mounted) return;
    if (session != null) {
      setState(() {
        _welcomeName = '${session.user.name} ${session.user.lastname}'.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrador'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(
              context,
              'profile',
              arguments: 'SYSTEM_ADMIN',
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF652580),
              Color(0xFF5a469c),
              Color(0xFF00A099),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _welcomeName.isEmpty ? 'Administrador del sistema' : _welcomeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestiona empresas, usuarios, cambios críticos y auditoría.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.05,
                    children: [
                      _tile(
                        icon: Icons.apartment,
                        title: 'Empresas',
                        subtitle: 'Aprobar o rechazar',
                        color: const Color(0xFF1E3A5F),
                        onTap: () =>
                            Navigator.pushNamed(context, 'admin/companies'),
                      ),
                      _tile(
                        icon: Icons.people_alt,
                        title: 'Usuarios',
                        subtitle: 'Listado y acciones',
                        color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.pushNamed(context, 'admin/users'),
                      ),
                      _tile(
                        icon: Icons.verified_user,
                        title: 'Cambio de contacto',
                        subtitle: 'Aprobar o rechazar',
                        color: const Color(0xFF00695C),
                        onTap: () => Navigator.pushNamed(
                          context,
                          'admin/contact-change-requests',
                        ),
                      ),
                      _tile(
                        icon: Icons.history_edu,
                        title: 'Historial global',
                        subtitle: 'Todas las solicitudes',
                        color: const Color(0xFF6A1B9A),
                        onTap: () =>
                            Navigator.pushNamed(context, 'admin/global-history'),
                      ),
                      _tile(
                        icon: Icons.swap_horiz,
                        title: 'Cambiar rol',
                        subtitle: 'Volver al menú',
                        color: const Color(0xFFBF360C),
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, 'roles'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
