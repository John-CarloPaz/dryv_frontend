import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Services/mapbox_navigation_channel.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';

class BackendRoutingException implements Exception {
  final String code;
  final String message;

  BackendRoutingException(this.code, this.message);

  @override
  String toString() => 'BackendRoutingException($code): $message';
}

/// Calls your backend to obtain the single backend-approved safest route.
///
/// IMPORTANT:
/// - This service MUST NOT call Mapbox Directions APIs.
/// - It must treat the backend as the single source of truth.
class BackendRoutingService {
  final Uri safestRouteEndpoint;
  final http.Client _client;

  BackendRoutingService({
    required this.safestRouteEndpoint,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<BackendApprovedRoute> fetchSafestRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    AppFileLogger.instance.info(
      'Fetching safest route: endpoint=$safestRouteEndpoint origin=${origin.lat},${origin.lng} dest=${destination.lat},${destination.lng}',
    );

    final body = jsonEncode({
      'origin': {'lat': origin.lat, 'lng': origin.lng},
      'destination': {'lat': destination.lat, 'lng': destination.lng},
      'vehicle_type': 'car',
    });

    late final http.Response resp;
    try {
      resp = await _client.post(
        safestRouteEndpoint,
        headers: {'content-type': 'application/json'},
        body: body,
      );
    } on SocketException catch (e) {
      AppFileLogger.instance.error(
        'Backend unreachable (SocketException): endpoint=$safestRouteEndpoint message=${e.message} osError=${e.osError}',
        err: e,
      );

      final endpointStr = safestRouteEndpoint.toString();
      final host = safestRouteEndpoint.host;
      final port = safestRouteEndpoint.hasPort ? safestRouteEndpoint.port : 80;

      // Helpful hints for the most common Flutter/Android networking gotchas.
      final hints = <String>[
        'Tried: $endpointStr',
        'If using Android emulator: use `http://10.0.2.2:<port>` instead of your PC LAN IP.',
        'If using a real phone: ensure phone and PC are on the same Wi‑Fi, your server listens on `0.0.0.0` (not `127.0.0.1`), and Windows Firewall allows inbound on port $port.',
        'If connected via USB: you can run `adb reverse tcp:$port tcp:$port` and then set the URL to `http://127.0.0.1:$port` on the device.',
      ].join(' ');

      throw BackendRoutingException(
        'BACKEND_UNREACHABLE',
        'No route to host / cannot connect to $host:$port. ${e.message}. $hints',
      );
    } catch (e) {
      AppFileLogger.instance.error('Backend unreachable: endpoint=$safestRouteEndpoint', err: e);
      throw BackendRoutingException('BACKEND_UNREACHABLE', e.toString());
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final snippet = resp.body.length > 800 ? '${resp.body.substring(0, 800)}...' : resp.body;
      AppFileLogger.instance.error(
        'Backend HTTP error: status=${resp.statusCode} body=$snippet',
      );
      throw BackendRoutingException(
        'BACKEND_HTTP_${resp.statusCode}',
        'Backend returned HTTP ${resp.statusCode}',
      );
    }

    AppFileLogger.instance.info('Backend response OK (bytes=${resp.body.length}).');

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      AppFileLogger.instance.error('Backend invalid JSON: not an object');
      throw BackendRoutingException('BACKEND_INVALID_JSON', 'Expected JSON object');
    }

    final status = decoded['status'];
    if (status != 'ok') {
      AppFileLogger.instance.error('Backend status not ok: status=$status');
      throw BackendRoutingException('BACKEND_STATUS_NOT_OK', 'status=$status');
    }

    final route = decoded['route'];
    if (route is! Map<String, dynamic>) {
      AppFileLogger.instance.error('Backend missing route object');
      throw BackendRoutingException('BACKEND_MISSING_ROUTE', 'Missing route object');
    }

    final waypointsRaw = route['waypoints'];
    if (waypointsRaw is! List) {
      throw BackendRoutingException('BACKEND_MISSING_WAYPOINTS', 'Missing waypoints');
    }

    final waypoints = <LatLng>[];
    int? maxRiskLevel;
    for (final w in waypointsRaw) {
      if (w is! Map) continue;
      final lat = w['lat'];
      final lng = w['lng'];
      if (lat is num && lng is num) {
        waypoints.add(LatLng(lat: lat.toDouble(), lng: lng.toDouble()));
      }

      final risk = _tryParseRiskLevel(w);
      if (risk != null) {
        maxRiskLevel = maxRiskLevel == null ? risk : (risk > maxRiskLevel! ? risk : maxRiskLevel);
      }
    }

    if (waypoints.length < 2) {
      AppFileLogger.instance.error('Backend returned <2 waypoints');
      throw BackendRoutingException('NO_SAFE_ROUTE', 'Backend returned <2 waypoints');
    }

    // NOTE:
    // We used to enforce that the backend route must start/end exactly on the
    // requested origin/destination. In practice, users may be on private
    // property or off-road and the backend may snap to the nearest routable
    // point. We keep this as a warning-only check for debugging.
    if (!_roughlySame(origin, waypoints.first) ||
        !_roughlySame(destination, waypoints.last)) {
      AppFileLogger.instance.warn(
        'Backend route endpoints differ from requested origin/destination. '
        'requestedOrigin=${origin.lat},${origin.lng} routeStart=${waypoints.first.lat},${waypoints.first.lng} '
        'requestedDest=${destination.lat},${destination.lng} routeEnd=${waypoints.last.lat},${waypoints.last.lng}',
      );
    }

    final routesRaw = route['routes'];
    if (routesRaw is! List || routesRaw.isEmpty || routesRaw.first is! Map) {
      AppFileLogger.instance.error('Backend missing routes array');
      throw BackendRoutingException('BACKEND_MISSING_ROUTES', 'Missing routes array');
    }

    final primaryRoute = routesRaw.first as Map;
    final geometry = primaryRoute['geometry'];

    // Optional summary fields.
    final distanceMeters = _tryParseDouble(primaryRoute['distance']);
    final durationSeconds = _tryParseDouble(primaryRoute['duration']);

    // Some backends send max risk at the route-level too.
    final routeMaxRisk = _tryParseInt(
      route['max_risk_level'] ??
          route['maxRiskLevel'] ??
          primaryRoute['max_risk_level'] ??
          primaryRoute['maxRiskLevel'],
    );
    if (routeMaxRisk != null) {
      maxRiskLevel = maxRiskLevel == null
          ? routeMaxRisk
          : (routeMaxRisk > maxRiskLevel! ? routeMaxRisk : maxRiskLevel);
    }

    // Optional but required for native turn-by-turn guidance.
    final directionsRouteJson = _extractDirectionsRouteJson(primaryRoute);
    AppFileLogger.instance.info(
      'Backend route parsed: waypoints=${waypoints.length} hasDirectionsRouteJson=${directionsRouteJson != null}',
    );

    return BackendApprovedRoute(
      waypoints: waypoints,
      geometryGeoJson: geometry,
      directionsRouteJson: directionsRouteJson,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      maxRiskLevel: maxRiskLevel,
    );
  }

  /// Keep a small tolerance because backend may round coordinates.
  bool _roughlySame(LatLng a, LatLng b) {
    const eps = 1e-5; // ~1 meter-ish in lat degrees
    return (a.lat - b.lat).abs() < eps && (a.lng - b.lng).abs() < eps;
  }

  String? _extractDirectionsRouteJson(Map primaryRoute) {
    final candidate = primaryRoute['directions_route_json'];
    if (candidate is String && candidate.trim().isNotEmpty) return candidate;

    final nested = primaryRoute['directionsRouteJson'];
    if (nested is String && nested.trim().isNotEmpty) return nested;

    final obj = primaryRoute['directions_route'];
    if (obj is Map) return jsonEncode(obj);

    return null;
  }

  int? _tryParseRiskLevel(Map w) {
    final candidate = w['risk_level'] ?? w['riskLevel'] ?? w['risk'] ?? w['riskLevelValue'];
    return _tryParseInt(candidate);
  }

  int? _tryParseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v.trim());
    }
    return null;
  }

  double? _tryParseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim());
    }
    return null;
  }
}

class BackendApprovedRoute {
  final List<LatLng> waypoints;

  /// GeoJSON geometry payload (for Flutter preview rendering).
  ///
  /// Type intentionally dynamic because backend may send either a GeoJSON object
  /// or a pre-serialized string.
  final dynamic geometryGeoJson;

  /// Mapbox DirectionsRoute JSON string (required to start native turn-by-turn).
  final String? directionsRouteJson;

  /// Optional distance summary in meters.
  final double? distanceMeters;

  /// Optional duration summary in seconds.
  final double? durationSeconds;

  /// Max risk level derived from waypoint risk fields (or route-level field, if present).
  final int? maxRiskLevel;

  const BackendApprovedRoute({
    required this.waypoints,
    required this.geometryGeoJson,
    required this.directionsRouteJson,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maxRiskLevel,
  });
}
