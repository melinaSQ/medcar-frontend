// lib/src/presentation/pages/profile/profile_page.dart

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcar_frontend/dependency_injection.dart' as di;
import 'package:medcar_frontend/navigation/route_observer.dart';
import 'package:medcar_frontend/src/data/datasources/remote/company_admin_remote_datasource.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with RouteAware, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _requestEmailController = TextEditingController();
  final _requestPhoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Perfil solo-empresa (admin de empresa aprobado).
  final _companyNameController = TextEditingController();
  final _companyRucController = TextEditingController();
  final _companyPhoneEditController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _isRequestingContactChange = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _hasPendingContactRequest = false;
  String _activeRole = 'USER';

  /// Solicitud de empresa del usuario (si aplica).
  Map<String, dynamic>? _myCompanyReg;
  bool _showCompanyRegistrationTile = false;

  /// Roles según sesión (se actualizan con socket / GET users/me).
  List<String> _accountRoles = [];

  SocketService? _profileSocket;
  StreamSubscription<void>? _profileSocketSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncProfileFromServer();
    _listenProfileSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roleArgument = ModalRoute.of(context)?.settings.arguments;
    if (roleArgument is String && roleArgument.isNotEmpty) {
      _activeRole = roleArgument.toUpperCase();
    }
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _profileSocketSub?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _lastnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _requestEmailController.dispose();
    _requestPhoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _companyRucController.dispose();
    _companyPhoneEditController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncProfileFromServer();
    }
  }

  @override
  void didPopNext() {
    _syncProfileFromServer();
  }

  /// Refresca correo/teléfono cuando el admin aprueba o rechaza sin salir de esta pantalla.
  Future<void> _listenProfileSocket() async {
    final session = await di.sl<AuthRepository>().getUserSession();
    if (!mounted || session == null) return;
    _profileSocket = di.sl<SocketService>();
    _profileSocket!.connect(session.accessToken);
    _profileSocketSub = _profileSocket!.userProfileUpdated.listen((_) {
      if (mounted) {
        _syncProfileFromServer();
      }
    });
  }

  /// Sincroniza usuario con el servidor y actualiza los campos en pantalla.
  Future<void> _syncProfileFromServer() async {
    try {
      await di.sl<AuthRepository>().refreshUserSession();
    } catch (_) {
      // Sin red o sin sesión: se muestran datos locales.
    }
    if (mounted) {
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final authRepo = di.sl<AuthRepository>();
    final session = await authRepo.getUserSession();
    if (session != null) {
      final pe = session.user.pendingEmail;
      final pp = session.user.pendingPhone;
      final ru = session.user.roles.map((e) => e.toUpperCase()).toList();
      final skipCompany = ru.contains('COMPANY_ADMIN') ||
          ru.contains('ADMIN') ||
          ru.contains('SYSTEM_ADMIN');
      Map<String, dynamic>? co;
      final loadCompanyRecord = !skipCompany || ru.contains('COMPANY_ADMIN');
      if (loadCompanyRecord) {
        try {
          co = await di.sl<CompanyAdminRemoteDataSource>().getMyCompany(
            token: session.accessToken,
          );
        } catch (_) {}
      }
      final isCompanyAdmin = ru.contains('COMPANY_ADMIN');
      if (co != null && isCompanyAdmin) {
        _companyNameController.text = (co['name'] ?? '').toString();
        _companyRucController.text = (co['ruc'] ?? '').toString();
        _companyPhoneEditController.text = (co['phone'] ?? '').toString();
      }
      setState(() {
        _nameController.text = session.user.name;
        _lastnameController.text = session.user.lastname;
        _phoneController.text = session.user.phone;
        _emailController.text = session.user.email;
        _hasPendingContactRequest = (pe != null && pe.isNotEmpty) ||
            (pp != null && pp.isNotEmpty);
        _myCompanyReg = co;
        _showCompanyRegistrationTile = !skipCompany;
        _accountRoles = List<String>.from(session.user.roles);
      });
    } else {
      setState(() {
        _myCompanyReg = null;
        _showCompanyRegistrationTile = false;
        _accountRoles = [];
      });
      _companyNameController.clear();
      _companyRucController.clear();
      _companyPhoneEditController.clear();
    }
  }

  /// Solo datos de empresa: admin de empresa con solicitud aprobada y sin rol de administrador del sistema.
  bool get _companyOnlyProfileMode {
    if (_activeRole != 'COMPANY_ADMIN') return false;
    final ru = _accountRoles.map((e) => e.toUpperCase()).toList();
    if (!ru.contains('COMPANY_ADMIN')) return false;
    if (ru.contains('SYSTEM_ADMIN') || ru.contains('ADMIN')) return false;
    final co = _myCompanyReg;
    if (co == null) return false;
    return co['status']?.toString().toUpperCase() == 'APPROVED';
  }

  String _roleLabelEs(String role) {
    switch (role.toUpperCase()) {
      case 'USER':
        return 'Usuario';
      case 'DRIVER':
        return 'Conductor';
      case 'COMPANY_ADMIN':
        return 'Admin de empresa';
      case 'ADMIN':
      case 'SYSTEM_ADMIN':
        return 'Administrador';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'USER':
        return Icons.person_outline;
      case 'DRIVER':
        return Icons.local_shipping_outlined;
      case 'COMPANY_ADMIN':
        return Icons.business_outlined;
      case 'ADMIN':
      case 'SYSTEM_ADMIN':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  String _companyRegSubtitle() {
    if (_myCompanyReg == null) {
      return 'Solicita el rol de administrador de empresa (requiere aprobación del sistema).';
    }
    switch (_myCompanyReg!['status']?.toString().toUpperCase()) {
      case 'PENDING':
        return 'Solicitud en revisión. Toca para ver detalles.';
      case 'REJECTED':
        return 'Solicitud rechazada. Toca para corregir y reenviar.';
      case 'APPROVED':
        return 'Empresa aprobada. Si no ves el panel, vuelve al menú de roles y actualiza sesión.';
      default:
        return 'Toca para continuar.';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      await authRepo.updateProfile(
        name: _nameController.text.trim(),
        lastname: _lastnameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perfil actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCompanyProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      final session = await authRepo.getUserSession();
      if (session == null) {
        throw Exception('Sesión no válida');
      }
      await di.sl<CompanyAdminRemoteDataSource>().updateMyCompany(
        name: _companyNameController.text.trim(),
        phone: _companyPhoneEditController.text.trim(),
        token: session.accessToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos de la empresa actualizados'),
            backgroundColor: Colors.green,
          ),
        );
        await _syncProfileFromServer();
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nueva contraseña debe tener al menos 8 caracteres'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      await authRepo.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contraseña cambiada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isChangingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestContactChange() async {
    final email = _requestEmailController.text.trim();
    final phone = _requestPhoneController.text.trim();

    if (email.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un nuevo correo o celular para solicitar cambio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRequestingContactChange = true;
    });

    try {
      final authRepo = di.sl<AuthRepository>();
      await authRepo.requestContactChange(
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Un administrador debe aprobar el cambio.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _requestEmailController.clear();
        _requestPhoneController.clear();
        await _syncProfileFromServer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingContactChange = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_companyOnlyProfileMode) {
      return _buildCompanyOnlyProfile(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Editar',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _syncProfileFromServer();
                setState(() {
                  _isEditing = false;
                });
              },
              tooltip: 'Cancelar',
            ),
        ],
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_accountRoles.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Roles en tu cuenta',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _accountRoles.map((r) {
                          final label = _roleLabelEs(r);
                          return Chip(
                            avatar: Icon(
                              _roleIcon(r),
                              size: 18,
                              color: const Color(0xFF652580),
                            ),
                            label: Text(label),
                            backgroundColor: Colors.grey.shade100,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_hasPendingContactRequest)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.hourglass_top,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Cambio de correo o celular pendiente de aprobación del administrador.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_showCompanyRegistrationTile) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              'company/register',
                              arguments: _myCompanyReg,
                            );
                            if (mounted) await _syncProfileFromServer();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.business_center,
                                  color: Colors.blueGrey.shade800,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Empresa de ambulancias',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _companyRegSubtitle(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.blueGrey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Nombre
                    TextFormField(
                      controller: _nameController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: !_isEditing,
                        fillColor: _isEditing ? null : Colors.grey[100],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Apellido
                    TextFormField(
                      controller: _lastnameController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        labelText: 'Apellido',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: !_isEditing,
                        fillColor: _isEditing ? null : Colors.grey[100],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El apellido es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email (solo lectura)
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        helperText:
                            'Cambio de correo requiere aprobación del administrador',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Teléfono
                    TextFormField(
                      controller: _phoneController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        helperText:
                            'Cambio de celular requiere aprobación del administrador',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El teléfono es requerido';
                        }
                        if (value.length < 7) {
                          return 'El teléfono debe tener al menos 7 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    // Botón guardar (solo cuando está editando)
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF652580),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Guardar Cambios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Solicitar cambio de contacto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para cambiar correo o celular, envía una solicitud y espera la aprobación del administrador.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _requestEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Nuevo correo (opcional)',
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _requestPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nuevo celular (opcional)',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isRequestingContactChange
                          ? null
                          : _requestContactChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isRequestingContactChange
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        _isRequestingContactChange
                            ? 'Enviando...'
                            : 'Enviar Solicitud',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    // Divider
                    const Divider(),
                    const SizedBox(height: 24),
                    // Sección de cambio de contraseña
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cambiar Contraseña',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isChangingPassword
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              _isChangingPassword = !_isChangingPassword;
                              if (!_isChangingPassword) {
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isChangingPassword) ...[
                      const SizedBox(height: 16),
                      // Contraseña actual
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: !_showCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña Actual',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCurrentPassword = !_showCurrentPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña actual es requerida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Nueva contraseña
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNewPassword = !_showNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: 'Mínimo 8 caracteres',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La nueva contraseña es requerida';
                          }
                          if (value.length < 8) {
                            return 'La contraseña debe tener al menos 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirmar contraseña
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Nueva Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor confirma la nueva contraseña';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Botón cambiar contraseña
                      ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Cambiar Contraseña',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompanyOnlyProfile(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de la empresa'),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Editar',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _syncProfileFromServer();
                setState(() => _isEditing = false);
              },
              tooltip: 'Cancelar',
            ),
        ],
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.business,
                          size: 60,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Administras esta empresa. Aquí solo se muestran y editan sus datos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _companyNameController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la empresa',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: !_isEditing,
                        fillColor: _isEditing ? null : Colors.grey[100],
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
                      controller: _companyRucController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'RUC / NIT',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        helperText:
                            'El RUC no se puede modificar desde la app',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyPhoneEditController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        labelText: 'Teléfono de la empresa',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: !_isEditing,
                        fillColor: _isEditing ? null : Colors.grey[100],
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Requerido';
                        }
                        if (v.trim().length < 7) {
                          return 'Al menos 7 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveCompanyProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF652580),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
