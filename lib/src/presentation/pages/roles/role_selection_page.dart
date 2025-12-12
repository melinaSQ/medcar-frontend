// lib/src/presentation/pages/roles/role_selection_page.dart

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
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
  Map<String, dynamic>? _activeRequest;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authRepo = sl<AuthRepository>();
    final session = await authRepo.getUserSession();

    if (session != null) {
      // Verificar si hay solicitud activa
      try {
        final dataSource = sl<ServiceRequestRemoteDataSource>();
        _activeRequest = await dataSource.getActiveRequest(token: session.accessToken);
      } catch (e) {
        // Ignorar errores al verificar solicitud activa
      }

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
              
              // Alerta si hay solicitud activa
              if (_activeRequest != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tienes una solicitud activa (${_activeRequest!['status']})',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),

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
                        subtitle: _activeRequest != null 
                            ? '⚠️ Tienes una solicitud activa' 
                            : 'Solicitar una ambulancia',
                        color: const Color(0xFF652580),
                        onTap: () => Navigator.pushReplacementNamed(context, 'client/home'),
                        hasWarning: _activeRequest != null,
                      ),
                      
                      // Mostrar opción de conductor si tiene el rol
                      if (_userRoles.contains('DRIVER'))
                        _buildRoleCard(
                          icon: Icons.local_shipping,
                          title: 'Conductor',
                          subtitle: 'Iniciar turno y atender emergencias',
                          color: const Color(0xFF2E7D32),
                          onTap: () {
                            if (_activeRequest != null) {
                              _showActiveRequestWarning('conductor');
                            } else {
                              Navigator.pushReplacementNamed(context, 'driver/home');
                            }
                          },
                          isDisabled: _activeRequest != null,
                        ),
                      
                      // Mostrar opción de admin si tiene el rol
                      if (_userRoles.contains('COMPANY_ADMIN'))
                        _buildRoleCard(
                          icon: Icons.business,
                          title: 'Admin de Empresa',
                          subtitle: 'Gestionar ambulancias y asignar solicitudes',
                          color: const Color(0xFF1E3A5F),
                          onTap: () {
                            if (_activeRequest != null) {
                              _showActiveRequestWarning('admin');
                            } else {
                              Navigator.pushReplacementNamed(context, 'company/home');
                            }
                          },
                          isDisabled: _activeRequest != null,
                        ),
                      
                      // Mostrar opción de super admin si tiene el rol
                      if (_userRoles.contains('ADMIN'))
                        _buildRoleCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Administrador',
                          subtitle: 'Gestión del sistema',
                          color: const Color(0xFF8B0000),
                          onTap: () {
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

  void _showActiveRequestWarning(String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 10),
            Text('Solicitud Activa'),
          ],
        ),
        content: Text(
          'No puedes cambiar al rol de $role mientras tienes una solicitud de ambulancia activa.\n\n'
          'Cancela o espera a que se complete tu solicitud actual.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool hasWarning = false,
  }) {
    final cardColor = isDisabled ? Colors.grey.shade300 : Colors.white;
    final iconColor = isDisabled ? Colors.grey : color;
    final textColor = isDisabled ? Colors.grey : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: isDisabled ? 1 : 4,
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
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (hasWarning) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: hasWarning ? Colors.orange : Colors.grey[600],
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

