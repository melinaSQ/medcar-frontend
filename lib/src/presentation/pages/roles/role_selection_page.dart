// lib/src/presentation/pages/roles/role_selection_page.dart

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  List<String> _userRoles = [];
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authRepo = sl<AuthRepository>();
    final session = await authRepo.getUserSession();

    if (session != null) {
      setState(() {
        _userRoles = session.user.roles;
        _userName = '${session.user.name} ${session.user.lastname}';
        _isLoading = false;
      });
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, 'login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Logo
              Image.asset(
                'assets/img/medcar_logo_color.png',
                width: 180,
                height: 90,
              ),
              
              const SizedBox(height: 20),
              
              // Saludo
              Text(
                'Hola, $_userName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                '¿Cómo deseas continuar?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Opciones de roles
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListView(
                    children: [
                      // Siempre mostrar opción de usuario/cliente
                      _buildRoleCard(
                        icon: Icons.person,
                        title: 'Usuario',
                        subtitle: 'Solicitar una ambulancia',
                        color: const Color(0xFF652580),
                        onTap: () => Navigator.pushReplacementNamed(context, 'client/home'),
                      ),
                      
                      // Mostrar opción de conductor si tiene el rol
                      if (_userRoles.contains('DRIVER'))
                        _buildRoleCard(
                          icon: Icons.local_shipping,
                          title: 'Conductor',
                          subtitle: 'Iniciar turno y atender emergencias',
                          color: const Color(0xFF2E7D32),
                          onTap: () => Navigator.pushReplacementNamed(context, 'driver/home'),
                        ),
                      
                      // Mostrar opción de admin si tiene el rol
                      if (_userRoles.contains('COMPANY_ADMIN'))
                        _buildRoleCard(
                          icon: Icons.business,
                          title: 'Admin de Empresa',
                          subtitle: 'Gestionar ambulancias y asignar solicitudes',
                          color: const Color(0xFF1E3A5F),
                          onTap: () => Navigator.pushReplacementNamed(context, 'company/home'),
                        ),
                      
                      // Mostrar opción de super admin si tiene el rol
                      if (_userRoles.contains('ADMIN'))
                        _buildRoleCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Administrador',
                          subtitle: 'Gestión del sistema',
                          color: const Color(0xFF8B0000),
                          onTap: () {
                            // TODO: Implementar admin home
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Próximamente...')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              
              // Botón de cerrar sesión
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextButton.icon(
                  onPressed: () async {
                    final authRepo = sl<AuthRepository>();
                    await authRepo.logout();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

