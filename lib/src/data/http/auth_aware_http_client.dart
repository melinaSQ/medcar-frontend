import 'package:http/http.dart' as http;
import 'package:medcar_frontend/src/data/http/unauthorized_session_handler.dart';

/// Envuelve [http.Client] y reacciona a 401 en peticiones que envían Bearer token.
class AuthAwareHttpClient extends http.BaseClient {
  AuthAwareHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      final auth =
          request.headers['Authorization'] ?? request.headers['authorization'];
      if (auth != null && auth.isNotEmpty) {
        UnauthorizedSessionHandler.handle();
      }
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
  }
}
