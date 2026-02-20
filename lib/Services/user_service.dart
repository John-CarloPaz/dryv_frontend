import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Models/app_user.dart';

class UserServiceException implements Exception {
  final String message;
  const UserServiceException(this.message);

  @override
  String toString() => message;
}

class UserService {
  final http.Client _client;

  UserService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  Future<AppUser> fetchCurrentUser({required String token}) async {
    if (_baseUrl.trim().isEmpty) {
      throw const UserServiceException(
        'Backend URL not configured. Set API_BASE_URL in .env',
      );
    }

    if (token.trim().isEmpty) {
      throw const UserServiceException('Not authenticated.');
    }

    final resp = await _client
        .get(
          _uri('/auth/me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeJson(resp);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final userJson = _extractUserJson(decoded);
      if (userJson == null) throw const UserServiceException('Invalid user payload.');
      return AppUser.fromJson(userJson);
    }

    if (resp.statusCode == 401) {
      throw const UserServiceException('Session expired. Please log in again.');
    }

    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      throw UserServiceException(message);
    }

    throw UserServiceException('Request failed (HTTP ${resp.statusCode}).');
  }

  Map<String, dynamic>? _extractUserJson(Map<String, dynamic> decoded) {
    final wrapped = decoded['user'];
    if (wrapped is Map) return wrapped.cast<String, dynamic>();

    // Laravel's default /api/user returns the user object directly.
    if (decoded.containsKey('id') || decoded.containsKey('email')) {
      return decoded;
    }

    return null;
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }
}
