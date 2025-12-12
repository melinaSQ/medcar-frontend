// lib/src/data/repositories/service_request_repository_impl.dart

import 'package:medcar_frontend/src/data/datasources/remote/service_request_remote_datasource.dart';
import 'package:medcar_frontend/src/domain/entities/service_request_entity.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/domain/repositories/service_request_repository.dart';

class ServiceRequestRepositoryImpl implements ServiceRequestRepository {
  final ServiceRequestRemoteDataSource remoteDataSource;
  final AuthRepository authRepository;

  ServiceRequestRepositoryImpl({
    required this.remoteDataSource,
    required this.authRepository,
  });

  @override
  Future<Map<String, dynamic>> createServiceRequest({
    required EmergencyType emergencyType,
    required double latitude,
    required double longitude,
    String? originDescription,
  }) async {
    // Obtener el token de la sesión actual
    final session = await authRepository.getUserSession();
    if (session == null) {
      throw Exception('No hay sesión activa');
    }

    return await remoteDataSource.createServiceRequest(
      emergencyType: emergencyType,
      latitude: latitude,
      longitude: longitude,
      originDescription: originDescription,
      token: session.accessToken,
    );
  }
}

