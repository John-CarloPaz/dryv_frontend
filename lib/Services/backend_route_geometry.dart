import 'dart:convert';

import 'package:dryvmobapp/Models/lat_lng.dart';

class BackendRouteGeometry {
  /// Attempts to extract a GeoJSON LineString coordinate list from [geometryGeoJson].
  ///
  /// Accepts either:
  /// - a decoded GeoJSON map
  /// - a JSON string containing a GeoJSON Feature or Geometry
  static List<LatLng>? tryExtractLineStringCoordinates(
    dynamic geometryGeoJson,
  ) {
    try {
      dynamic obj = geometryGeoJson;
      if (obj is String) {
        obj = jsonDecode(obj);
      }

      if (obj is! Map) return null;

      dynamic geom = obj;
      if (obj['type'] == 'Feature' && obj['geometry'] is Map) {
        geom = obj['geometry'];
      }

      if (geom is! Map) return null;
      if (geom['type'] != 'LineString') return null;

      final coords = geom['coordinates'];
      if (coords is! List) return null;

      final out = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = c[0];
          final lat = c[1];
          if (lng is num && lat is num) {
            out.add(LatLng(lat: lat.toDouble(), lng: lng.toDouble()));
          }
        }
      }

      return out.length >= 2 ? out : null;
    } catch (_) {
      return null;
    }
  }

  static String lineStringGeoJsonFromLatLngs(List<LatLng> coordinates) {
    final coords = coordinates
        .map((p) => <double>[p.lng, p.lat])
        .toList(growable: false);

    return jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': coords},
      'properties': <String, dynamic>{},
    });
  }
}
