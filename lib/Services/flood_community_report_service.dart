import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';

enum FloodDepthLevel {
  ankleDeep(1, 'Ankle-Deep'),
  kneeDeep(2, 'Knee-Deep'),
  waistDeep(3, 'Waist-Deep'),
  chestDeep(4, 'Chest-Deep');

  final int estimatedDepth;
  final String label;

  const FloodDepthLevel(this.estimatedDepth, this.label);
}

class FloodCommunityReportServiceException implements Exception {
  final String message;
  const FloodCommunityReportServiceException(this.message);

  @override
  String toString() => message;
}

class FloodCommunityReportService {
  final http.Client _client;

  FloodCommunityReportService({http.Client? client})
      : _client = client ?? http.Client();

  String get _baseUrl {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  Future<String?> _readAuthToken() async {
    // Keep this key consistent with lib/Providers/auth_provider.dart
    const key = 'auth_token';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(key);
    if (token == null) return null;
    final trimmed = token.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> submit({
    required LatLng location,
    required FloodDepthLevel depthLevel,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      throw const FloodCommunityReportServiceException(
        'Backend URL not configured. Set API_BASE_URL in .env',
      );
    }

    final token = await _readAuthToken();

    final body = jsonEncode({
      // Be liberal in what we send; backend can choose the fields it uses.
      'report_lat': location.lat,
      'report_lng': location.lng,
      'lat': location.lat,
      'lng': location.lng,
      'estimated_depth': depthLevel.estimatedDepth,
      'estimated_depth_label': depthLevel.label,
    });

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late final http.Response resp;
    try {
      resp = await _client
          .post(_uri('/flood/community-report'), headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw FloodCommunityReportServiceException(e.toString());
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    String message = 'Request failed (HTTP ${resp.statusCode}).';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        final m = decoded['message'];
        if (m is String && m.trim().isNotEmpty) message = m;
        final err = decoded['error'];
        if (err is String && err.trim().isNotEmpty) message = err;
      }
    } catch (_) {}

    throw FloodCommunityReportServiceException(message);
  }
}
