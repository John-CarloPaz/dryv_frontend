import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Models/lat_lng.dart';
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
    String vehicleType = 'car',
    bool avoidMotorways = false,
  }) async {
    AppFileLogger.instance.info(
      'Fetching safest route: endpoint=$safestRouteEndpoint origin=${origin.lat},${origin.lng} dest=${destination.lat},${destination.lng} vehicleType=$vehicleType avoidMotorways=$avoidMotorways',
    );

    final body = jsonEncode({
      'origin': {'lat': origin.lat, 'lng': origin.lng},
      'destination': {'lat': destination.lat, 'lng': destination.lng},
      'vehicle_type': vehicleType,
      'avoid_motorway': avoidMotorways,
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
      AppFileLogger.instance.error(
        'Backend unreachable: endpoint=$safestRouteEndpoint',
        err: e,
      );
      throw BackendRoutingException('BACKEND_UNREACHABLE', e.toString());
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final snippet = resp.body.length > 800
          ? '${resp.body.substring(0, 800)}...'
          : resp.body;
      AppFileLogger.instance.error(
        'Backend HTTP error: status=${resp.statusCode} body=$snippet',
      );
      throw BackendRoutingException(
        'BACKEND_HTTP_${resp.statusCode}',
        'Backend returned HTTP ${resp.statusCode}',
      );
    }

    AppFileLogger.instance.info(
      'Backend response OK (bytes=${resp.body.length}).',
    );

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      AppFileLogger.instance.error('Backend invalid JSON: not an object');
      throw BackendRoutingException(
        'BACKEND_INVALID_JSON',
        'Expected JSON object',
      );
    }

    // Backwards-compatible status handling.
    // Old backend: { status: 'ok', route: {...} }
    // New backend: { code: 'Ok', routes: [...], waypoints: [...] }
    final status = decoded['status'];
    final code = decoded['code'];
    final ok =
        (status is String && status.toLowerCase() == 'ok') ||
        (code is String && code.toLowerCase() == 'ok');
    if (!ok) {
      AppFileLogger.instance.error(
        'Backend status not ok: status=$status code=$code',
      );
      throw BackendRoutingException(
        'BACKEND_STATUS_NOT_OK',
        'status=$status code=$code',
      );
    }

    // Old backend wrapped route under `route`, new backend returns route payload at top-level.
    final dynamic routeCandidate = decoded['route'] is Map<String, dynamic>
        ? decoded['route']
        : decoded;
    if (routeCandidate is! Map<String, dynamic>) {
      AppFileLogger.instance.error('Backend missing route payload');
      throw BackendRoutingException(
        'BACKEND_MISSING_ROUTE',
        'Missing route payload',
      );
    }

    final route = routeCandidate;

    final waypointsRaw = route['waypoints'];
    if (waypointsRaw is! List) {
      throw BackendRoutingException(
        'BACKEND_MISSING_WAYPOINTS',
        'Missing waypoints',
      );
    }

    final waypoints = <LatLng>[];
    int? maxRiskLevel;
    for (final w in waypointsRaw) {
      if (w is! Map) continue;

      // Old shape: { lat: <num>, lng: <num>, ... }
      // New shape: { name: <str>, location: [<lng>, <lat>] }
      final lat = w['lat'];
      final lng = w['lng'];
      if (lat is num && lng is num) {
        waypoints.add(LatLng(lat: lat.toDouble(), lng: lng.toDouble()));
      } else {
        final loc = w['location'] ?? w['coordinates'];
        if (loc is List && loc.length >= 2) {
          final locLng = loc[0];
          final locLat = loc[1];
          if (locLat is num && locLng is num) {
            waypoints.add(
              LatLng(lat: locLat.toDouble(), lng: locLng.toDouble()),
            );
          }
        }
      }

      final risk = _tryParseRiskLevel(w);
      if (risk != null) {
        final currentMax = maxRiskLevel;
        maxRiskLevel = currentMax == null
            ? risk
            : (risk > currentMax ? risk : currentMax);
      }
    }

    if (waypoints.length < 2) {
      AppFileLogger.instance.error('Backend returned <2 waypoints');
      throw BackendRoutingException(
        'NO_SAFE_ROUTE',
        'Backend returned <2 waypoints',
      );
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
      throw BackendRoutingException(
        'BACKEND_MISSING_ROUTES',
        'Missing routes array',
      );
    }

    final primaryRoute = routesRaw.first as Map;
    final geometry = primaryRoute['geometry'];

    try {
      if (geometry is Map) {
        final t = geometry['type'];
        final coords = geometry['coordinates'];
        final n = coords is List ? coords.length : null;
        AppFileLogger.instance.info(
          'Backend geometry: type=$t coordCount=${n ?? 'unknown'}',
        );
      } else {
        AppFileLogger.instance.info(
          'Backend geometry: runtimeType=${geometry.runtimeType}',
        );
      }
    } catch (_) {
      // Ignore logging errors.
    }

    // Optional summary fields.
    final distanceMeters = _tryParseDouble(primaryRoute['distance']);
    final durationSeconds = _tryParseDouble(primaryRoute['duration']);

    // Some backends send max risk at the route-level too.
    final meta = route['_meta'];
    final routeMaxRisk = _tryParseInt(
      route['max_risk_level'] ??
          route['maxRiskLevel'] ??
          (meta is Map
              ? meta['max_risk_level'] ?? meta['maxRiskLevel']
              : null) ??
          primaryRoute['max_risk_level'] ??
          primaryRoute['maxRiskLevel'],
    );
    if (routeMaxRisk != null) {
      final currentMax = maxRiskLevel;
      maxRiskLevel = currentMax == null
          ? routeMaxRisk
          : (routeMaxRisk > currentMax ? routeMaxRisk : currentMax);
    }

    // Persist legs/steps/maneuvers for custom Flutter-side turn-by-turn.
    // Prefer `routes[0].legs`, but fall back to decoding directions_route_json /
    // directions_route if legs aren't present at the top level.
    final primaryRouteRaw = Map<String, dynamic>.from(primaryRoute);
    final primaryRouteRawJson = jsonEncode(primaryRouteRaw);

    final stepsJson = _extractStepsJson(primaryRouteRaw);

    AppFileLogger.instance.info(
      'Backend route parsed: waypoints=${waypoints.length} stepsJson=${stepsJson?.length ?? 0}',
    );

    return BackendApprovedRoute(
      waypoints: waypoints,
      geometryGeoJson: geometry,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      maxRiskLevel: maxRiskLevel,
      primaryRouteRawJson: primaryRouteRawJson,
      primaryRouteRaw: primaryRouteRaw,
      stepsJson: stepsJson,
    );
  }

  /// Keep a small tolerance because backend may round coordinates.
  bool _roughlySame(LatLng a, LatLng b) {
    const eps = 1e-5; // ~1 meter-ish in lat degrees
    return (a.lat - b.lat).abs() < eps && (a.lng - b.lng).abs() < eps;
  }

  List<Map<String, dynamic>>? _extractStepsJson(
    Map<String, dynamic> primaryRoute,
  ) {
    List<dynamic>? legs;

    final directLegs = primaryRoute['legs'];
    if (directLegs is List) {
      legs = directLegs;
    }

    // If legs are absent, optionally fall back to directions_route(_json)
    // depending on how the backend payload is shaped.
    if (legs == null || legs.isEmpty) {
      Map<String, dynamic>? directionsRoute;

      final directionsRouteObj = primaryRoute['directions_route'];
      if (directionsRouteObj is Map) {
        directionsRoute = Map<String, dynamic>.from(directionsRouteObj);
      } else {
        final candidate =
            primaryRoute['directions_route_json'] ??
            primaryRoute['directionsRouteJson'];
        if (candidate is String && candidate.trim().isNotEmpty) {
          try {
            final dyn = jsonDecode(candidate);
            if (dyn is Map<String, dynamic>) directionsRoute = dyn;
          } catch (_) {
            // Ignore decode issues; step storage remains null.
          }
        }
      }

      final fallbackLegs = directionsRoute?['legs'];
      if (fallbackLegs is List) {
        legs = fallbackLegs;
      }
    }

    if (legs == null || legs.isEmpty) return null;
    final leg0 = legs.first;
    if (leg0 is! Map) return null;

    final stepsRaw = leg0['steps'];
    if (stepsRaw is! List) return null;

    final stepsJson = <Map<String, dynamic>>[];
    for (final step in stepsRaw) {
      if (step is Map) {
        stepsJson.add(Map<String, dynamic>.from(step));
      }
    }

    return stepsJson;
  }

  int? _tryParseRiskLevel(Map w) {
    final candidate =
        w['risk_level'] ?? w['riskLevel'] ?? w['risk'] ?? w['riskLevelValue'];
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

  /// Raw steps list for custom Flutter-side turn-by-turn.
  ///
  /// Source: `routes[0].legs[0].steps` (or decoded from directions_route(_json)).
  final List<Map<String, dynamic>>? stepsJson;

  /// Optional distance summary in meters.
  final double? distanceMeters;

  /// Optional duration summary in seconds.
  final double? durationSeconds;

  /// Max risk level derived from waypoint risk fields (or route-level field, if present).
  final int? maxRiskLevel;

  /// Raw `routes[0]` payload (decoded JSON map) returned by the backend.
  ///
  /// This is used for custom Flutter-side turn-by-turn (without Mapbox Nav SDK).
  final Map<String, dynamic>? primaryRouteRaw;

  /// Raw `routes[0]` payload, serialized as JSON.
  ///
  /// Useful for persistence / logging / debugging.
  final String? primaryRouteRawJson;

  const BackendApprovedRoute({
    required this.waypoints,
    required this.geometryGeoJson,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maxRiskLevel,
    this.primaryRouteRaw,
    this.primaryRouteRawJson,
    this.stepsJson,
  });
}
