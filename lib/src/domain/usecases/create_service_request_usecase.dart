// lib/src/domain/usecases/create_service_request_usecase.dart

import 'package:medcar_frontend/src/domain/entities/service_request_entity.dart';
import 'package:medcar_frontend/src/domain/repositories/service_request_repository.dart';

class CreateServiceRequestUseCase {
  final ServiceRequestRepository _repository;

  CreateServiceRequestUseCase(this._repository);

  Future<Map<String, dynamic>> call({
    required EmergencyType emergencyType,
    required double latitude,
    required double longitude,
    String? originDescription,
  }) async {
    return await _repository.createServiceRequest(
      emergencyType: emergencyType,
      latitude: latitude,
      longitude: longitude,
      originDescription: originDescription,
    );
  }
}

