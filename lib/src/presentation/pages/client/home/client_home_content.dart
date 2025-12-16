// ignore_for_file: deprecated_member_use, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';

class ClientHomeContent extends StatelessWidget {
  final ClientHomeState state;

  const ClientHomeContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.status == ClientHomeStatus.loaded
              ? 'Hola, ${state.userName}'
              : 'MedCar',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF652580),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Mi Perfil',
            onPressed: () {
              Navigator.pushNamed(context, 'profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Cambiar rol',
            onPressed: () {
              Navigator.pushReplacementNamed(context, 'roles');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, 'client/history');
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.history, color: Color(0xFF652580)),
        tooltip: 'Ver historial',
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (state.status == ClientHomeStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF652580)),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF652580), Color(0xFF00A099)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/img/medcar_logo_color.png',
                  width: 200,
                  height: 100,
                ),
                const SizedBox(height: 40),

                // Botón principal
                _buildEmergencyButton(context),

                const SizedBox(height: 30),

                // Texto informativo
                const Text(
                  'Presiona el botón para solicitar una ambulancia',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, 'client/map');
      },
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital, size: 60, color: Colors.white),
            SizedBox(height: 8),
            Text(
              'EMERGENCIA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ClientHomeBloc>().add(LogoutEvent());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}
