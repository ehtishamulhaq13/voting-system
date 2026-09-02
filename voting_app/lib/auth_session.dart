import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists API token and user snapshot for authenticated requests.
class AuthSession {
  static const _kToken = 'voting_auth_token';
  static const _kUser = 'voting_auth_user_json';

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  static Future<Map<String, String>> authHeaders() async {
    final t = await getToken();
    return {
      'Accept': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  static Future<void> saveSession({
    required String? token,
    required Map<String, dynamic> user,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await p.setString(_kToken, token);
    } else {
      await p.remove(_kToken);
    }
    await p.setString(_kUser, jsonEncode(user));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
  }
}
