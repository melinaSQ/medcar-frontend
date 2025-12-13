// lib/src/presentation/pages/driver/home/bloc/driver_home_event.dart

abstract class DriverHomeEvent {}

class DriverHomeInitEvent extends DriverHomeEvent {}

class StartShiftEvent extends DriverHomeEvent {
  final String plate;
  final String code;

  StartShiftEvent({required this.plate, required this.code});
}

class EndShiftEvent extends DriverHomeEvent {}

class UpdateStatusEvent extends DriverHomeEvent {
  final String newStatus;

  UpdateStatusEvent({required this.newStatus});
}

class LogoutEvent extends DriverHomeEvent {}

class MissionCanceledEvent extends DriverHomeEvent {}
