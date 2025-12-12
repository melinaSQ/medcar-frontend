// lib/src/presentation/pages/company/home/bloc/company_home_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/data/datasources/remote/shifts_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'company_home_event.dart';
import 'company_home_state.dart';

class CompanyHomeBloc extends Bloc<CompanyHomeEvent, CompanyHomeState> {
  final AuthRepository authRepository;
  final ServiceRequestRemoteDataSource serviceRequestDataSource;
  final ShiftsRemoteDataSource shiftsDataSource;

  CompanyHomeBloc({
    required this.authRepository,
    required this.serviceRequestDataSource,
    required this.shiftsDataSource,
  }) : super(CompanyHomeState()) {
    on<CompanyHomeInitEvent>(_onInit);
    on<LoadPendingRequestsEvent>(_onLoadPendingRequests);
    on<LoadActiveShiftsEvent>(_onLoadActiveShifts);
    on<AssignRequestEvent>(_onAssignRequest);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onInit(CompanyHomeInitEvent event, Emitter<CompanyHomeState> emit) async {
    emit(state.copyWith(status: CompanyHomeStatus.loading));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        final userName = '${session.user.name} ${session.user.lastname}';
        
        // Cargar solicitudes pendientes y turnos activos
        final requests = await serviceRequestDataSource.getPendingRequests(
          token: session.accessToken,
        );
        final shifts = await shiftsDataSource.getActiveShifts(
          token: session.accessToken,
        );

        emit(state.copyWith(
          status: CompanyHomeStatus.loaded,
          userName: userName,
          pendingRequests: requests,
          activeShifts: shifts,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CompanyHomeStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLoadPendingRequests(LoadPendingRequestsEvent event, Emitter<CompanyHomeState> emit) async {
    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        final requests = await serviceRequestDataSource.getPendingRequests(
          token: session.accessToken,
        );
        emit(state.copyWith(pendingRequests: requests));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLoadActiveShifts(LoadActiveShiftsEvent event, Emitter<CompanyHomeState> emit) async {
    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        final shifts = await shiftsDataSource.getActiveShifts(
          token: session.accessToken,
        );
        emit(state.copyWith(activeShifts: shifts));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onAssignRequest(AssignRequestEvent event, Emitter<CompanyHomeState> emit) async {
    emit(state.copyWith(status: CompanyHomeStatus.assigning));

    try {
      final session = await authRepository.getUserSession();
      if (session != null) {
        await serviceRequestDataSource.assignRequest(
          requestId: event.requestId,
          shiftId: event.shiftId,
          token: session.accessToken,
        );

        // Recargar solicitudes pendientes
        final requests = await serviceRequestDataSource.getPendingRequests(
          token: session.accessToken,
        );

        emit(state.copyWith(
          status: CompanyHomeStatus.assigned,
          pendingRequests: requests,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CompanyHomeStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<CompanyHomeState> emit) async {
    await authRepository.logout();
  }
}

