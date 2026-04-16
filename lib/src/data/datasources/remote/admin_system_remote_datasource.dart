// Admin del sistema (rol ADMIN).
//
// Contrato esperado con NestJS (ajusta rutas si tu backend usa otros paths):
// - GET    /admin/companies/pending     → empresas pendientes de aprobación
// - PATCH  /companies/:id/approve       → aprobar (Bearer token)
// - PATCH  /companies/:id/reject       → rechazar
// - GET    /admin/users?q=             → todos los usuarios (búsqueda opcional)
// - PATCH  /admin/users/:id/block      → bloquear
// - PATCH  /admin/users/:id/unblock    → desbloquear
// - DELETE /admin/users/:id            → eliminar
// - GET    /admin/users/:id/service-requests → historial de solicitudes del usuario
// - GET    /admin/service-requests     → historial global (auditoría)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

List<Map<String, dynamic>> _decodeListMap(dynamic decoded) {
  if (decoded is List) {
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (decoded is Map<String, dynamic>) {
    final data = decoded['data'] ?? decoded['items'] ?? decoded['results'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }
  return [];
}

abstract class AdminSystemRemoteDataSource {
  Future<List<Map<String, dynamic>>> getPendingCompanies({
    required String token,
  });

  Future<void> approveCompany({
    required int companyId,
    required String token,
  });

  Future<void> rejectCompany({
    required int companyId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getAllUsers({
    required String token,
    String? searchQuery,
  });

  Future<void> blockUser({
    required int userId,
    required String token,
  });

  Future<void> unblockUser({
    required int userId,
    required String token,
  });

  Future<void> deleteUser({
    required int userId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getPendingContactChangeRequests({
    required String token,
    String? searchQuery,
  });

  Future<void> approveContactChange({
    required int userId,
    required String token,
  });

  Future<void> rejectContactChange({
    required int userId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getUserServiceRequestHistory({
    required int userId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getGlobalServiceRequests({
    required String token,
  });
}

class AdminSystemRemoteDataSourceImpl implements AdminSystemRemoteDataSource {
  final http.Client client;

  AdminSystemRemoteDataSourceImpl({required this.client});

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  @override
  Future<List<Map<String, dynamic>>> getPendingCompanies({
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/admin/companies/pending'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return _decodeListMap(decoded);
    }
    throw Exception(_errorMessage(response));
  }

  @override
  Future<void> approveCompany({
    required int companyId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/companies/$companyId/approve'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<void> rejectCompany({
    required int companyId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/companies/$companyId/reject'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllUsers({
    required String token,
    String? searchQuery,
  }) async {
    final q = searchQuery?.trim();
    final uri = Uri.parse('$apiUrl/admin/users').replace(
      queryParameters: (q != null && q.isNotEmpty) ? {'q': q} : null,
    );

    final response = await client.get(uri, headers: _headers(token));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return _decodeListMap(decoded);
    }
    throw Exception(_errorMessage(response));
  }

  @override
  Future<void> blockUser({
    required int userId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/admin/users/$userId/block'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<void> unblockUser({
    required int userId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/admin/users/$userId/unblock'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<void> deleteUser({
    required int userId,
    required String token,
  }) async {
    final response = await client.delete(
      Uri.parse('$apiUrl/admin/users/$userId'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingContactChangeRequests({
    required String token,
    String? searchQuery,
  }) async {
    final q = searchQuery?.trim();
    final uri = Uri.parse('$apiUrl/admin/users/contact-change-requests').replace(
      queryParameters: (q != null && q.isNotEmpty) ? {'q': q} : null,
    );

    final response = await client.get(uri, headers: _headers(token));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return _decodeListMap(decoded);
    }
    throw Exception(_errorMessage(response));
  }

  @override
  Future<void> approveContactChange({
    required int userId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/admin/users/$userId/contact-change/approve'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<void> rejectContactChange({
    required int userId,
    required String token,
  }) async {
    final response = await client.patch(
      Uri.parse('$apiUrl/admin/users/$userId/contact-change/reject'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserServiceRequestHistory({
    required int userId,
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/admin/users/$userId/service-requests'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return _decodeListMap(decoded);
    }
    throw Exception(_errorMessage(response));
  }

  @override
  Future<List<Map<String, dynamic>>> getGlobalServiceRequests({
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/admin/service-requests'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return _decodeListMap(decoded);
    }
    throw Exception(_errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {}
    return 'Error ${response.statusCode}: ${response.body}';
  }
}
