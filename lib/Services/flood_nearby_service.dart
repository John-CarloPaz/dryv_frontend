import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Models/flood_nearby.dart';
import 'package:dryvmobapp/Models/lat_lng.dart';

class FloodNearbyServiceException implements Exception {
  final String message;
  const FloodNearbyServiceException(this.message);
  @override
  String toString() => message;
}

class FloodNearbyService {
  final http.Client _client;

  FloodNearbyService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Uri _uri(String path, Map<String, String> query) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p').replace(queryParameters: query);
  }

  Future<FloodNearbyResponse> fetchNearby({required LatLng location}) async {
    if (_baseUrl.trim().isEmpty) {
      throw const FloodNearbyServiceException(
        'Backend URL not configured. Set API_BASE_URL in .env',
      );
    }

    final uri = _uri('/flood/nearby', {
      'lat': location.lat.toString(),
      'lng': location.lng.toString(),
    });

    final resp = await _client.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw FloodNearbyServiceException(
        'Flood endpoint failed (HTTP ${resp.statusCode}).',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const FloodNearbyServiceException('Invalid JSON response.');
    }

    final parsed = FloodNearbyResponse.fromJson(
      decoded.cast<String, dynamic>(),
    );
    return parsed;
  }
}
