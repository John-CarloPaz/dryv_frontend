import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:dryvmobapp/Services/app_file_logger.dart';

/// Platform channel bridge for native Mapbox Navigation (Android).
///
/// SAFETY/SECURITY:
/// - This app must NOT compute or modify routes.
/// - We only hand the backend-approved route/waypoints to Android.
/// - Android must run with reroute/refresh disabled.
class MapboxNavigationChannel {
  static const MethodChannel _channel = MethodChannel('mapbox_navigation');

  /// Sends a backend-approved route to Android.
  ///
  /// [coordinates] are the full ordered coordinate list (origin + silent intermediates + destination).
  /// [waypointIndices] declares the *non-silent* waypoints. For silent intermediates, this should
  /// typically be `[0, coordinates.length - 1]`.
  ///
  /// If provided, [directionsRouteJson] must be a Mapbox DirectionsRoute JSON
  /// (not a full DirectionsResponse).
  ///
  /// If omitted, Android may request a route preview from Mapbox using the
  /// backend-provided waypoints.
  static Future<void> setApprovedRoute({
    required List<LatLng> coordinates,
    required List<int> waypointIndices,
    String? directionsRouteJson,
    String? originLabel,
    String? destinationLabel,
    double? distanceMeters,
    double? durationSeconds,
    int? maxRiskLevel,
  }) async {
    if (coordinates.length < 2) {
      throw PlatformException(
        code: 'INVALID_WAYPOINTS',
        message: 'At least origin and destination are required.',
      );
    }

    AppFileLogger.instance.info(
      'Sending approved route to Android: coords=${coordinates.length} waypointIndices=$waypointIndices directionsRouteJsonBytes=${directionsRouteJson?.length ?? 0}',
    );

    final payload = <String, dynamic>{
      'coordinates': coordinates
          .map((p) => <String, double>{'lat': p.lat, 'lng': p.lng})
          .toList(growable: false),
      'waypointIndices': waypointIndices,
      if (directionsRouteJson != null)
        // Keep it as a string to avoid lossy Map conversions.
        'directionsRouteJson': directionsRouteJson,
      if (originLabel != null) 'originLabel': originLabel,
      if (destinationLabel != null) 'destinationLabel': destinationLabel,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (maxRiskLevel != null) 'maxRiskLevel': maxRiskLevel,
    };

    try {
      await _channel.invokeMethod<void>('setApprovedRoute', payload);
    } on PlatformException catch (e, st) {
      AppFileLogger.instance.error('setApprovedRoute failed', err: e, stack: st);
      rethrow;
    }
  }

  /// Launches native turn-by-turn navigation (Mapbox drop-in UI) on Android.
  ///
  /// Android will refuse to start if no approved route has been set.
  static Future<void> startNavigation() async {
    AppFileLogger.instance.info('Starting native navigation (Android)');
    try {
      await _channel.invokeMethod<void>('startNavigation');
    } on PlatformException catch (e, st) {
      AppFileLogger.instance.error('startNavigation failed', err: e, stack: st);
      rethrow;
    }
  }

  /// Clears any stored approved route on Android.
  static Future<void> clearRoute() async {
    AppFileLogger.instance.info('Clearing approved route (Android)');
    try {
      await _channel.invokeMethod<void>('clearRoute');
    } on PlatformException catch (e, st) {
      AppFileLogger.instance.error('clearRoute failed', err: e, stack: st);
      rethrow;
    }
  }
}

class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  static LatLng fromJson(Map<String, dynamic> json) {
    return LatLng(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// Helper to extract a DirectionsRoute JSON string from backend JSON.
///
/// The backend response example in your spec only includes `geometry`.
/// For native Mapbox turn-by-turn (banners/voice), Android needs a *full* DirectionsRoute
/// (legs/steps/instructions), serialized as Mapbox DirectionsRoute JSON.
///
/// Recommended backend field (example):
/// `route.routes[0].directions_route_json`  (a JSON string)
String? extractDirectionsRouteJson(Map<String, dynamic> backendRoute) {
  final candidate = backendRoute['directions_route_json'];
  if (candidate is String && candidate.trim().isNotEmpty) return candidate;

  // Back-compat: sometimes teams send it nested.
  final nested = backendRoute['directionsRouteJson'];
  if (nested is String && nested.trim().isNotEmpty) return nested;

  // Some backends may send a full JSON object; if so, stringify it.
  final obj = backendRoute['directions_route'];
  if (obj is Map<String, dynamic>) return jsonEncode(obj);

  return null;
}
