// lib/src/domain/repositories/service_request_repository.dart

import 'package:medcar_frontend/src/domain/entities/service_request_entity.dart';

abstract class ServiceRequestRepository {
  Future<Map<String, dynamic>> createServiceRequest({
    required EmergencyType emergencyType,
    required double latitude,
    required double longitude,
    String? originDescription,
  });

  Future<void> cancelServiceRequest({required int requestId});
}

