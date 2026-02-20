import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthResponse {
  final Map<String, dynamic> user;
  final String token;
  final String tokenType;

  const AuthResponse({
    required this.user,
    required this.token,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user:
          (json['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      token: (json['token'] as String?) ?? '',
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
    );
  }
}

class AuthService {
  const AuthService();

  String get _baseUrl {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
    String deviceName = 'web',
  }) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    final Map<String, dynamic> json = _decodeJson(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final auth = AuthResponse.fromJson(json);
      if (auth.token.isEmpty) {
        throw const AuthServiceException(
          'Login succeeded but token is missing.',
        );
      }
      return auth;
    }

    throw AuthServiceException(_extractErrorMessage(json, res.statusCode));
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String deviceName = 'web',
  }) async {
    final res = await http.post(
      _uri('/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': deviceName,
      }),
    );

    final Map<String, dynamic> json = _decodeJson(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final auth = AuthResponse.fromJson(json);
      if (auth.token.isEmpty) {
        throw const AuthServiceException(
          'Registration succeeded but token is missing.',
        );
      }
      return auth;
    }

    throw AuthServiceException(_extractErrorMessage(json, res.statusCode));
  }

  Future<void> forgotPasswordOtp({required String email}) async {
    final res = await http.post(
      _uri('/auth/forgot-password-otp'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final Map<String, dynamic> json = _decodeJson(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    throw AuthServiceException(_extractErrorMessage(json, res.statusCode));
  }

  Future<void> resetPasswordOtp({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await http.post(
      _uri('/auth/reset-password-otp'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final Map<String, dynamic> json = _decodeJson(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    throw AuthServiceException(_extractErrorMessage(json, res.statusCode));
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _extractErrorMessage(Map<String, dynamic> json, int statusCode) {
    final message = json['message'];
    if (message is String && message.trim().isNotEmpty) return message;

    final error = json['error'];
    if (error is String && error.trim().isNotEmpty) return error;

    final errors = json['errors'];
    if (errors is Map) {
      final flattened = <String>[];
      for (final entry in errors.entries) {
        final v = entry.value;
        if (v is List) {
          for (final item in v) {
            if (item is String && item.trim().isNotEmpty) flattened.add(item);
          }
        }
      }
      if (flattened.isNotEmpty) return flattened.first;
    }

    return 'Request failed (HTTP $statusCode).';
  }
}

class AuthServiceException implements Exception {
  final String message;
  const AuthServiceException(this.message);

  @override
  String toString() => message;
}
