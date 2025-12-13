// lib/src/presentation/pages/driver/home/bloc/driver_home_bloc.dart

// ignore_for_file: avoid_print

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/data/datasources/remote/driver_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'driver_home_event.dart';
import 'driver_home_state.dart';

class DriverHomeBloc extends Bloc<DriverHomeEvent, DriverHomeState> {
  final AuthRepository authRepository;
  final DriverRemoteDataSource driverDataSource;

  DriverHomeBloc({required this.authRepository, required this.driverDataSource})
    : super(DriverHomeState()) {
    on<DriverHomeInitEvent>(_onInit);
    on<StartShiftEvent>(_onStartShift);
    on<EndShiftEvent>(_onEndShift);
    on<UpdateStatusEvent>(_onUpdateStatus);
    on<LogoutEvent>(_onLogout);
    on<_ReceiveMissionEvent>(_onReceiveMission);
    on<MissionCanceledEvent>(_onMissionCanceled);
  }

  void _onMissionCanceled(
    MissionCanceledEvent event,
    Emitter<DriverHomeState> emit,
  ) {
    print('🚫 BLoC: Procesando MissionCanceledEvent');
    print(
      '🚫 BLoC: Estado anterior: ${state.status}, mission: ${state.currentMission != null}',
    );
    // Volver al estado de turno activo sin misión
    emit(state.copyWith(status: DriverHomeStatus.hasShift, clearMission: true));
    print('🚫 BLoC: Nuevo estado emitido: hasShift, clearMission: true');
  }

  void _onReceiveMission(
    _ReceiveMissionEvent event,
    Emitter<DriverHomeState> emit,
  ) {
    emit(
      state.copyWith(
        status: DriverHomeStatus.hasMission,
        currentMission: event.mission,
      ),
    );
  }

  Future<void> _onInit(
    DriverHomeInitEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    emit(state.copyWith(status: DriverHomeStatus.loading));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        final userName = '${session.user.name} ${session.user.lastname}';

        // Verificar si hay un turno activo
        final activeShift = await driverDataSource.getMyActiveShift(
          token: session.accessToken,
        );

        if (activeShift != null) {
          // Hay turno activo - verificar si tiene misión
          final activeMission = activeShift['activeMission'];

          if (activeMission != null) {
            // Tiene turno Y misión activa
            emit(
              state.copyWith(
                status: DriverHomeStatus.hasMission,
                userName: userName,
                activeShift: activeShift,
                currentMission: activeMission,
              ),
            );
          } else {
            // Tiene turno pero sin misión
            emit(
              state.copyWith(
                status: DriverHomeStatus.hasShift,
                userName: userName,
                activeShift: activeShift,
              ),
            );
          }
        } else {
          // No hay turno activo
          emit(
            state.copyWith(
              status: DriverHomeStatus.noShift,
              userName: userName,
            ),
          );
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DriverHomeStatus.error,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onStartShift(
    StartShiftEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    emit(state.copyWith(status: DriverHomeStatus.loading));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        final shift = await driverDataSource.startShift(
          plate: event.plate,
          code: event.code,
          token: session.accessToken,
        );

        emit(
          state.copyWith(status: DriverHomeStatus.hasShift, activeShift: shift),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DriverHomeStatus.noShift,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onEndShift(
    EndShiftEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    emit(state.copyWith(status: DriverHomeStatus.loading));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        await driverDataSource.endShift(token: session.accessToken);

        emit(
          state.copyWith(
            status: DriverHomeStatus.noShift,
            clearShift: true,
            clearMission: true,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DriverHomeStatus.hasShift,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onUpdateStatus(
    UpdateStatusEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (state.currentMission == null) return;

    emit(state.copyWith(status: DriverHomeStatus.updating));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        // El ID puede venir directo o dentro de requestDetails
        final mission = state.currentMission!;
        final requestDetails =
            mission['requestDetails'] as Map<String, dynamic>?;
        final requestId = requestDetails?['id'] ?? mission['id'];

        if (requestId == null) {
          throw Exception('No se encontró el ID de la solicitud');
        }

        final updatedMission = await driverDataSource.updateRequestStatus(
          requestId: requestId is int
              ? requestId
              : int.parse(requestId.toString()),
          status: event.newStatus,
          token: session.accessToken,
        );

        // Si el estado es COMPLETED, limpiar la misión
        if (event.newStatus == 'COMPLETED') {
          emit(
            state.copyWith(
              status: DriverHomeStatus.hasShift,
              clearMission: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: DriverHomeStatus.hasMission,
              currentMission: updatedMission,
            ),
          );
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DriverHomeStatus.hasMission,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    await authRepository.logout();
  }

  // Método para recibir nueva misión desde WebSocket
  void receiveMission(Map<String, dynamic> mission) {
    add(_ReceiveMissionEvent(mission: mission));
  }
}

// Evento interno para recibir misión
class _ReceiveMissionEvent extends DriverHomeEvent {
  final Map<String, dynamic> mission;
  _ReceiveMissionEvent({required this.mission});
}
