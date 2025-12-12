import 'package:equatable/equatable.dart';

enum ClientHomeStatus { initial, loading, loaded, loggedOut, error }

class ClientHomeState extends Equatable {
  final String userName;
  final ClientHomeStatus status;
  final String? errorMessage;

  const ClientHomeState({
    this.userName = '',
    this.status = ClientHomeStatus.initial,
    this.errorMessage,
  });

  ClientHomeState copyWith({
    String? userName,
    ClientHomeStatus? status,
    String? errorMessage,
  }) {
    return ClientHomeState(
      userName: userName ?? this.userName,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [userName, status, errorMessage];
}
