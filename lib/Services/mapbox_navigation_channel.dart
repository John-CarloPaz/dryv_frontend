/// Deprecated: the app now uses Flutter-native route preview + driving screens.
///
/// This stub remains only to prevent silent usage of the old Android platform
/// channel bridge.
@Deprecated('Use Flutter-native RoutePreviewScreen/DrivingScreen instead.')
class MapboxNavigationChannel {
  static Future<void> setApprovedRoute({
    required List<dynamic> coordinates,
    required List<int> waypointIndices,
    String? directionsRouteJson,
    String? originLabel,
    String? destinationLabel,
    double? distanceMeters,
    double? durationSeconds,
    int? maxRiskLevel,
  }) {
    throw UnsupportedError(
      'MapboxNavigationChannel is deprecated. Use Flutter navigation screens.',
    );
  }

  static Future<void> startNavigation() {
    throw UnsupportedError(
      'MapboxNavigationChannel is deprecated. Use Flutter navigation screens.',
    );
  }

  static Future<void> clearRoute() {
    throw UnsupportedError(
      'MapboxNavigationChannel is deprecated. Use Flutter navigation screens.',
    );
  }
}
