// lib/src/domain/entities/service_request_entity.dart

enum EmergencyType {
  trafficAccident,
  medicalEmergency,
  other,
}

extension EmergencyTypeExtension on EmergencyType {
  String get value {
    switch (this) {
      case EmergencyType.trafficAccident:
        return 'TRAFFIC_ACCIDENT';
      case EmergencyType.medicalEmergency:
        return 'MEDICAL_EMERGENCY';
      case EmergencyType.other:
        return 'OTHER';
    }
  }

  String get displayName {
    switch (this) {
      case EmergencyType.trafficAccident:
        return 'Accidente de tráfico';
      case EmergencyType.medicalEmergency:
        return 'Emergencia médica';
      case EmergencyType.other:
        return 'Otro';
    }
  }
}

class ServiceRequestEntity {
  final int id;
  final EmergencyType emergencyType;
  final double latitude;
  final double longitude;
  final String? originDescription;
  final String status;
  final DateTime createdAt;

  ServiceRequestEntity({
    required this.id,
    required this.emergencyType,
    required this.latitude,
    required this.longitude,
    this.originDescription,
    required this.status,
    required this.createdAt,
  });
}

