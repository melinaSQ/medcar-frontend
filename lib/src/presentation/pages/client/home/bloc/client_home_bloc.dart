import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';
import 'package:medcar_frontend/src/utils/service_request_status.dart';

class ClientHomeBloc extends Bloc<ClientHomeEvent, ClientHomeState> {
  final AuthRepository authRepository;
  final ServiceRequestRemoteDataSource serviceRequestDataSource;

  ClientHomeBloc({
    required this.authRepository,
    required this.serviceRequestDataSource,
  }) : super(const ClientHomeState()) {
    on<ClientHomeInitEvent>(_onInit);
    on<ClientHomeRefreshActiveRequestEvent>(_onRefreshActive);
    on<ClientHomeClearActiveRequestEvent>(_onClearActive);
    on<ClientHomeCancelActiveRequestEvent>(_onCancelActive);
    on<ClientHomeClearErrorEvent>(_onClearError);
    on<LogoutEvent>(_onLogout);
  }

  void _onClearError(ClientHomeClearErrorEvent event, Emitter<ClientHomeState> emit) {
    emit(state.copyWith(errorMessage: null));
  }

  Future<Map<String, dynamic>?> _fetchActive(String token) async {
    try {
      final raw = await serviceRequestDataSource.getActiveRequest(token: token);
      return _sanitizeActive(raw);
    } catch (_) {
      return null;
    }
  }

  /// El endpoint a veces sigue devolviendo la solicitud aunque ya esté cancelada/completada.
  Map<String, dynamic>? _sanitizeActive(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final status = normalizeServiceRequestStatus(
      raw['status']?.toString(),
      hasAssignedShift: raw['shift'] != null,
    );
    if (isTerminalClientActiveStatus(status)) return null;
    return raw;
  }

  void _onClearActive(
    ClientHomeClearActiveRequestEvent event,
    Emitter<ClientHomeState> emit,
  ) {
    emit(state.copyWith(clearActiveServiceRequest: true));
  }

  Future<void> _onInit(ClientHomeInitEvent event, Emitter<ClientHomeState> emit) async {
    emit(state.copyWith(status: ClientHomeStatus.loading));

    try {
      final session = await authRepository.getUserSession();
      if (session == null) {
        emit(state.copyWith(status: ClientHomeStatus.loggedOut));
        return;
      }

      final active = await _fetchActive(session.accessToken);

      emit(
        state.copyWith(
          userName: session.user.name,
          status: ClientHomeStatus.loaded,
          activeServiceRequest: active,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ClientHomeStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRefreshActive(
    ClientHomeRefreshActiveRequestEvent event,
    Emitter<ClientHomeState> emit,
  ) async {
    final session = await authRepository.getUserSession();
    if (session == null) return;
    final active = await _fetchActive(session.accessToken);
    emit(state.copyWith(activeServiceRequest: active));
  }

  Future<void> _onCancelActive(
    ClientHomeCancelActiveRequestEvent event,
    Emitter<ClientHomeState> emit,
  ) async {
    final req = state.activeServiceRequest;
    if (req == null) return;
    final rid = parseServiceRequestId(req['id']);
    if (rid == null) return;

    final session = await authRepository.getUserSession();
    if (session == null) return;

    final status = normalizeServiceRequestStatus(
      req['status']?.toString(),
      hasAssignedShift: req['shift'] != null,
    );
    if (status != 'SEARCHING' && status != 'ASSIGNED') {
      return;
    }

    try {
      await serviceRequestDataSource.cancelServiceRequest(
        requestId: rid,
        token: session.accessToken,
      );
      emit(state.copyWith(clearActiveServiceRequest: true));
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<ClientHomeState> emit) async {
    await authRepository.logout();
    emit(
      state.copyWith(
        status: ClientHomeStatus.loggedOut,
        clearActiveServiceRequest: true,
      ),
    );
  }
}
