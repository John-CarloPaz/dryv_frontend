import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dryvmobapp/Models/community_flooded_roads.dart';

class CommunityFloodedRoadsServiceException implements Exception {
  final String message;
  const CommunityFloodedRoadsServiceException(this.message);

  @override
  String toString() => message;
}

class CommunityFloodedRoadsService {
  final http.Client _client;

  CommunityFloodedRoadsService({http.Client? client})
    : _client = client ?? http.Client();

  String get _baseUrl {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Uri _uri(String path, Map<String, String> query) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p').replace(queryParameters: query);
  }

  Future<String?> _readAuthToken() async {
    // Keep consistent with lib/Providers/auth_provider.dart
    const key = 'auth_token';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(key);
    if (token == null) return null;
    final trimmed = token.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<CommunityFloodedRoadsResponse> fetchFloodedRoads({
    int minRiskLevel = 0,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      throw const CommunityFloodedRoadsServiceException(
        'Backend URL not configured. Set API_BASE_URL in .env',
      );
    }

    final uri = _uri('/flood/community-report/flooded-roads', {
      'min_risk_level': minRiskLevel.toString(),
    });

    final token = await _readAuthToken();
    if (token == null) {
      throw const CommunityFloodedRoadsServiceException(
        'Not authenticated. Please sign in to view community flood reports.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    late final http.Response resp;
    try {
      resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw CommunityFloodedRoadsServiceException(e.toString());
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message =
          'Community flood endpoint failed (HTTP ${resp.statusCode}).';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) {
          final m = decoded['message'];
          if (m is String && m.trim().isNotEmpty) message = m;
          final err = decoded['error'];
          if (err is String && err.trim().isNotEmpty) message = err;
        }
      } catch (_) {}

      throw CommunityFloodedRoadsServiceException(message);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const CommunityFloodedRoadsServiceException(
        'Invalid JSON response.',
      );
    }

    return CommunityFloodedRoadsResponse.fromJson(
      decoded.cast<String, dynamic>(),
    );
  }
}
