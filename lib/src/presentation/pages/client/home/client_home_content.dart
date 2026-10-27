// ignore_for_file: deprecated_member_use, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';
import 'package:medcar_frontend/src/utils/map_coercion.dart';
import 'package:medcar_frontend/src/utils/service_request_status.dart';

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
              Navigator.pushNamed(context, 'profile', arguments: 'USER');
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
                const SizedBox(height: 24),

                if (state.activeServiceRequest != null) ...[
                  _buildActiveRequestCard(context, state.activeServiceRequest!),
                  const SizedBox(height: 20),
                ],

                // Botón principal
                _buildEmergencyButton(context),

                const SizedBox(height: 30),

                // Texto informativo
                Text(
                  state.activeServiceRequest != null
                      ? 'También puedes iniciar otra solicitud cuando no tengas una activa'
                      : 'Presiona el botón para solicitar una ambulancia',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRequestCard(
    BuildContext context,
    Map<String, dynamic> req,
  ) {
    final status = normalizeServiceRequestStatus(
      req['status']?.toString(),
      hasAssignedShift: req['shift'] != null,
    );
    final id = parseServiceRequestId(req['id']);
    final pickup = _pickupLatLng(req);
    final canCancel = status == 'SEARCHING' || status == 'ASSIGNED';

    String statusLabel;
    switch (status) {
      case 'SEARCHING':
        statusLabel = 'Buscando ambulancia';
        break;
      case 'ASSIGNED':
        statusLabel = 'Ambulancia asignada';
        break;
      case 'ON_THE_WAY':
        statusLabel = 'En camino';
        break;
      case 'ON_SITE':
        statusLabel = 'En el lugar';
        break;
      case 'TRAVELLING':
        statusLabel = 'En traslado';
        break;
      default:
        statusLabel = status;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergencia en curso',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusLabel,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (id != null)
              Text(
                'Solicitud #$id',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pickup == null
                    ? null
                    : () async {
                        await Navigator.pushNamed(
                          context,
                          'client/tracking',
                          arguments: {
                            'userLat': pickup.latitude,
                            'userLng': pickup.longitude,
                            'requestId': id,
                          },
                        );
                        if (context.mounted) {
                          context
                              .read<ClientHomeBloc>()
                              .add(ClientHomeRefreshActiveRequestEvent());
                        }
                      },
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('Ver seguimiento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF652580),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (canCancel) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Cancelar emergencia?'),
                        content: const Text(
                          'Se cancelará tu solicitud activa. ¿Continuar?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Sí, cancelar'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      context
                          .read<ClientHomeBloc>()
                          .add(ClientHomeCancelActiveRequestEvent());
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    'Cancelar solicitud',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Coordenadas del punto de recogida (GeoJSON Point en originLocation).
  ({double latitude, double longitude})? _pickupLatLng(Map<String, dynamic> req) {
    final ol = coerceMap(req['originLocation']);
    final coords = ol?['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    return (latitude: lat, longitude: lon);
  }

  Widget _buildEmergencyButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, 'client/map');
        if (context.mounted) {
          context.read<ClientHomeBloc>().add(ClientHomeRefreshActiveRequestEvent());
        }
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
