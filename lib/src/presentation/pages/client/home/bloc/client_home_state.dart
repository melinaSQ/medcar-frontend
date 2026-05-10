import 'package:equatable/equatable.dart';

enum ClientHomeStatus { initial, loading, loaded, loggedOut, error }

class ClientHomeState extends Equatable {
  final String userName;
  final ClientHomeStatus status;
  final String? errorMessage;
  /// Solicitud de emergencia activa (SEARCHING…TRAVELLING), o null.
  final Map<String, dynamic>? activeServiceRequest;

  const ClientHomeState({
    this.userName = '',
    this.status = ClientHomeStatus.initial,
    this.errorMessage,
    this.activeServiceRequest,
  });

  ClientHomeState copyWith({
    String? userName,
    ClientHomeStatus? status,
    String? errorMessage,
    Map<String, dynamic>? activeServiceRequest,
    bool clearActiveServiceRequest = false,
  }) {
    return ClientHomeState(
      userName: userName ?? this.userName,
      status: status ?? this.status,
      errorMessage: errorMessage,
      activeServiceRequest: clearActiveServiceRequest
          ? null
          : (activeServiceRequest ?? this.activeServiceRequest),
    );
  }

  @override
  List<Object?> get props => [
        userName,
        status,
        errorMessage,
        activeServiceRequest?['id'],
        activeServiceRequest?['status'],
      ];
}
