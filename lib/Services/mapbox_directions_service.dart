import 'dart:convert';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MapboxDirectionsService {
  static String? _resolveAccessToken() {
    final candidates = <String?>[
      dotenv.env['MAPBOX_ACCESS_TOKEN'],
      dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'],
      dotenv.env['MAPBOX_TOKEN'],
    ];

    for (final token in candidates) {
      final trimmed = token?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Returns the primary route distance in meters, or null if unavailable.
  ///
  /// Uses Mapbox Directions API.
  static Future<int?> fetchDrivingDistanceMeters({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final token = _resolveAccessToken();
    if (token == null) return null;

    final coords =
        '${origin.lng},${origin.lat};${destination.lng},${destination.lat}';

    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/$profile/$coords',
      <String, String>{
        'access_token': token,
        'overview': 'false',
        'alternatives': 'false',
        'steps': 'false',
      },
    );

    final resp = await http.get(uri).timeout(timeout);
    if (resp.statusCode != 200) return null;

    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) return null;
    final routes = body['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final distance = first['distance'];
    if (distance is num) return distance.round();

    return null;
  }
}
