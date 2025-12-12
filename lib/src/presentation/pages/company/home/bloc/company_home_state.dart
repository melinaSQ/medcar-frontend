// lib/src/presentation/pages/company/home/bloc/company_home_state.dart

enum CompanyHomeStatus { initial, loading, loaded, error, assigning, assigned }

class CompanyHomeState {
  final CompanyHomeStatus status;
  final String userName;
  final List<Map<String, dynamic>> pendingRequests;
  final List<Map<String, dynamic>> activeShifts;
  final String? errorMessage;

  CompanyHomeState({
    this.status = CompanyHomeStatus.initial,
    this.userName = '',
    this.pendingRequests = const [],
    this.activeShifts = const [],
    this.errorMessage,
  });

  CompanyHomeState copyWith({
    CompanyHomeStatus? status,
    String? userName,
    List<Map<String, dynamic>>? pendingRequests,
    List<Map<String, dynamic>>? activeShifts,
    String? errorMessage,
  }) {
    return CompanyHomeState(
      status: status ?? this.status,
      userName: userName ?? this.userName,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeShifts: activeShifts ?? this.activeShifts,
      errorMessage: errorMessage,
    );
  }
}

