// lib/src/presentation/pages/driver/home/bloc/driver_home_state.dart

enum DriverHomeStatus { 
  initial, 
  loading, 
  noShift, 
  hasShift, 
  hasMission, 
  error,
  updating,
}

class DriverHomeState {
  final DriverHomeStatus status;
  final String userName;
  final Map<String, dynamic>? activeShift;
  final Map<String, dynamic>? currentMission;
  final String? errorMessage;

  DriverHomeState({
    this.status = DriverHomeStatus.initial,
    this.userName = '',
    this.activeShift,
    this.currentMission,
    this.errorMessage,
  });

  DriverHomeState copyWith({
    DriverHomeStatus? status,
    String? userName,
    Map<String, dynamic>? activeShift,
    Map<String, dynamic>? currentMission,
    String? errorMessage,
    bool clearShift = false,
    bool clearMission = false,
  }) {
    return DriverHomeState(
      status: status ?? this.status,
      userName: userName ?? this.userName,
      activeShift: clearShift ? null : (activeShift ?? this.activeShift),
      currentMission: clearMission ? null : (currentMission ?? this.currentMission),
      errorMessage: errorMessage,
    );
  }

  // Helper para obtener el estado actual de la misión
  String? get missionStatus => currentMission?['status'];
}

