// lib/src/data/datasources/remote/ratings_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/datasources/remote/auth_remote_datasource.dart';

abstract class RatingsRemoteDataSource {
  Future<Map<String, dynamic>> createRating({
    required int serviceRequestId,
    required int score,
    String? comment,
    required String token,
  });

  Future<Map<String, dynamic>> checkIfRated({
    required int serviceRequestId,
    required String token,
  });

  Future<Map<String, dynamic>> getAverageRating({
    required int userId,
    required String token,
  });

  Future<List<Map<String, dynamic>>> getMyRatings({required String token});
}

class RatingsRemoteDataSourceImpl implements RatingsRemoteDataSource {
  final http.Client client;

  RatingsRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> createRating({
    required int serviceRequestId,
    required int score,
    String? comment,
    required String token,
  }) async {
    final body = <String, dynamic>{
      'serviceRequestId': serviceRequestId,
      'score': score,
    };
    if (comment != null && comment.isNotEmpty) {
      body['comment'] = comment;
    }

    final response = await client.post(
      Uri.parse('$apiUrl/ratings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Error al enviar calificación');
    }
  }

  @override
  Future<Map<String, dynamic>> checkIfRated({
    required int serviceRequestId,
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/ratings/check/$serviceRequestId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {'hasRated': false};
    }
  }

  @override
  Future<Map<String, dynamic>> getAverageRating({
    required int userId,
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/ratings/average/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {'average': 0, 'count': 0};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMyRatings({
    required String token,
  }) async {
    final response = await client.get(
      Uri.parse('$apiUrl/ratings/my-ratings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }
}
