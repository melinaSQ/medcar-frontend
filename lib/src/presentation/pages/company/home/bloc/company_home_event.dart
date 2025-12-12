// lib/src/presentation/pages/company/home/bloc/company_home_event.dart

abstract class CompanyHomeEvent {}

class CompanyHomeInitEvent extends CompanyHomeEvent {}

class LoadPendingRequestsEvent extends CompanyHomeEvent {}

class LoadActiveShiftsEvent extends CompanyHomeEvent {}

class AssignRequestEvent extends CompanyHomeEvent {
  final int requestId;
  final int shiftId;

  AssignRequestEvent({required this.requestId, required this.shiftId});
}

class LogoutEvent extends CompanyHomeEvent {}

