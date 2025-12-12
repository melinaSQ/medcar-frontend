import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';

class ClientHomeBloc extends Bloc<ClientHomeEvent, ClientHomeState> {
  final AuthRepository authRepository;

  ClientHomeBloc({required this.authRepository}) : super(const ClientHomeState()) {
    
    on<ClientHomeInitEvent>((event, emit) async {
      emit(state.copyWith(status: ClientHomeStatus.loading));
      
      try {
        final session = await authRepository.getUserSession();
        if (session != null) {
          emit(state.copyWith(
            userName: session.user.name,
            status: ClientHomeStatus.loaded,
          ));
        } else {
          emit(state.copyWith(status: ClientHomeStatus.loggedOut));
        }
      } catch (e) {
        emit(state.copyWith(
          status: ClientHomeStatus.error,
          errorMessage: e.toString(),
        ));
      }
    });

    on<LogoutEvent>((event, emit) async {
      await authRepository.logout();
      emit(state.copyWith(status: ClientHomeStatus.loggedOut));
    });
  }
}

