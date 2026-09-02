import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth_session.dart';

/// Authenticated HTTP helpers (token from [AuthSession]). Does not modify [Api].
class VotingHttp {
  VotingHttp._();

  static Future<http.Response> get(String path) async {
    final headers = await AuthSession.authHeaders();
    return http.get(Api.uri(path), headers: headers);
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? body,
  }) async {
    final headers = await AuthSession.authHeaders();
    return http.post(Api.uri(path), headers: headers, body: body);
  }

  /// Sends multipart without overwriting the multipart Content-Type.
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request,
  ) async {
    final auth = await AuthSession.authHeaders();
    auth.forEach((key, value) {
      if (key.toLowerCase() != 'content-type') {
        request.headers[key] = value;
      }
    });
    return request.send();
  }
}
