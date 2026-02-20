import 'dart:convert';
import 'dart:math' as math;

import 'package:dryvmobapp/Models/lat_lng.dart';

class BackendRouteGeometry {
  /// Attempts to extract a route coordinate list from [geometryGeoJson].
  ///
  /// Accepts:
  /// - a decoded GeoJSON Feature or Geometry with `type=LineString`
  /// - a JSON string containing a GeoJSON Feature or Geometry
  /// - a raw coordinates list `[[lng, lat], ...]`
  /// - an encoded polyline string (Mapbox/Google polyline with precision 5 or 6)
  static List<LatLng>? tryExtractLineStringCoordinates(
    dynamic geometryGeoJson, {
    LatLng? originHint,
    LatLng? destinationHint,
  }) {
    try {
      dynamic obj = geometryGeoJson;

      // 1) Common case: backend now sends an encoded polyline string.
      if (obj is String) {
        final s = obj.trim();
        if (s.isEmpty) return null;

        // Try JSON first.
        try {
          obj = jsonDecode(s);
        } catch (_) {
          // Not JSON -> treat as encoded polyline.
          return _tryDecodePolylineFlexible(
            s,
            originHint: originHint,
            destinationHint: destinationHint,
          );
        }
      }

      // 2) Accept raw coordinate arrays.
      if (obj is List) {
        return _coordsListToLatLngs(obj);
      }

      if (obj is! Map) return null;

      // 3) Accept full backend payloads accidentally passed in.
      // Example: { routes: [ { geometry: { type: 'LineString', coordinates: [...] } } ] }
      final routesRaw = obj['routes'];
      if (routesRaw is List && routesRaw.isNotEmpty) {
        final first = routesRaw.first;
        if (first is Map) {
          final geom = first['geometry'];
          final coords = tryExtractLineStringCoordinates(
            geom,
            originHint: originHint,
            destinationHint: destinationHint,
          );
          if (coords != null) return coords;
        }
      }

      // 4) Accept route objects with an embedded geometry field.
      final embeddedGeometry = obj['geometry'];
      if (embeddedGeometry is Map ||
          embeddedGeometry is List ||
          embeddedGeometry is String) {
        final coords = tryExtractLineStringCoordinates(
          embeddedGeometry,
          originHint: originHint,
          destinationHint: destinationHint,
        );
        if (coords != null) return coords;
      }

      // Some backends wrap the geometry in a map.
      // Try common patterns first.
      final directCoords = obj['coordinates'];
      if (directCoords is List) {
        return _coordsListToLatLngs(directCoords);
      }

      final directPolyline =
          obj['polyline'] ?? obj['geometry'] ?? obj['encoded'];
      if (directPolyline is String && directPolyline.trim().isNotEmpty) {
        final decoded = _tryDecodePolylineFlexible(
          directPolyline.trim(),
          originHint: originHint,
          destinationHint: destinationHint,
        );
        if (decoded != null) return decoded;
      }

      dynamic geom = obj;
      if (obj['type'] == 'Feature' && obj['geometry'] is Map) {
        geom = obj['geometry'];
      }

      if (geom is! Map) return null;
      if (geom['type'] != 'LineString') return null;

      final coords = geom['coordinates'];
      if (coords is! List) return null;

      return _coordsListToLatLngs(coords);
    } catch (_) {
      return null;
    }
  }

  /// Builds a full coordinate list by concatenating per-step geometries.
  ///
  /// Useful as a fallback when the top-level `routes[0].geometry` is absent,
  /// incorrectly shaped, or callers accidentally pass only waypoints.
  static List<LatLng>? tryExtractFromStepsJson(
    List<Map<String, dynamic>>? stepsJson, {
    LatLng? originHint,
    LatLng? destinationHint,
  }) {
    if (stepsJson == null || stepsJson.isEmpty) return null;

    final out = <LatLng>[];
    for (final step in stepsJson) {
      final geom = step['geometry'];
      final seg = tryExtractLineStringCoordinates(
        geom,
        originHint: originHint,
        destinationHint: destinationHint,
      );
      if (seg == null || seg.length < 2) continue;

      // Ensure each step segment direction connects to previous segment.
      var segment = seg;
      if (out.isEmpty) {
        if (originHint != null) {
          final dF = _haversineMeters(originHint, seg.first);
          final dR = _haversineMeters(originHint, seg.last);
          if (dR + 0.01 < dF) {
            segment = seg.reversed.toList(growable: false);
          }
        }
      } else {
        final last = out.last;
        final dF = _haversineMeters(last, seg.first);
        final dR = _haversineMeters(last, seg.last);
        if (dR + 0.01 < dF) {
          segment = seg.reversed.toList(growable: false);
        }
      }

      if (out.isNotEmpty) {
        final last = out.last;
        final first = segment.first;
        // If segments connect, avoid duplicating the joint.
        // Use a distance tolerance to account for backend rounding.
        if (_haversineMeters(last, first) <= 2.0) {
          out.addAll(segment.skip(1));
          continue;
        }
      }
      out.addAll(segment);
    }

    if (out.length < 2) return null;
    // If available, orient using hints (helps if backend step order is reversed).
    if (originHint != null && destinationHint != null) {
      return orientOriginToDestination(
        out,
        origin: originHint,
        destination: destinationHint,
      );
    }
    return out;
  }

  static List<LatLng>? _coordsListToLatLngs(List coords) {
    final out = <LatLng>[];

    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lng = c[0];
        final lat = c[1];
        if (lng is num && lat is num) {
          final latD = lat.toDouble();
          final lngD = lng.toDouble();
          if (latD.isFinite &&
              lngD.isFinite &&
              latD.abs() <= 90 &&
              lngD.abs() <= 180) {
            out.add(LatLng(lat: latD, lng: lngD));
          }
        }
      }
    }

    return out.length >= 2 ? out : null;
  }

  static List<LatLng>? _tryDecodePolylineFlexible(
    String encoded, {
    LatLng? originHint,
    LatLng? destinationHint,
  }) {
    final five = _tryDecodePolyline(encoded, precision: 5);
    final six = _tryDecodePolyline(encoded, precision: 6);

    if (five == null) return six;
    if (six == null) return five;

    if (originHint != null && destinationHint != null) {
      final s5 = _endpointScore(five, originHint, destinationHint);
      final s6 = _endpointScore(six, originHint, destinationHint);
      return s6 + 0.01 < s5 ? six : five;
    }

    // Heuristic fallback: choose the decode with larger coordinate magnitude.
    final m5 = _maxAbsLatLng(five);
    final m6 = _maxAbsLatLng(six);
    return m6 > m5 ? six : five;
  }

  static double _endpointScore(
    List<LatLng> coords,
    LatLng origin,
    LatLng dest,
  ) {
    if (coords.length < 2) return double.infinity;
    final first = coords.first;
    final last = coords.last;
    final forward =
        _haversineMeters(origin, first) + _haversineMeters(dest, last);
    final reversed =
        _haversineMeters(origin, last) + _haversineMeters(dest, first);
    return forward < reversed ? forward : reversed;
  }

  static double _maxAbsLatLng(List<LatLng> coords) {
    double m = 0;
    for (final p in coords) {
      final a = p.lat.abs();
      final b = p.lng.abs();
      if (a > m) m = a;
      if (b > m) m = b;
    }
    return m;
  }

  static List<LatLng>? _tryDecodePolyline(
    String encoded, {
    required int precision,
  }) {
    try {
      if (encoded.isEmpty) return null;

      final factor = math.pow(10.0, precision).toDouble();
      int index = 0;
      int lat = 0;
      int lng = 0;
      final coords = <LatLng>[];

      while (index < encoded.length) {
        final dLat = _decodePolylineValue(
          encoded,
          refIndex: () => index,
          setIndex: (v) => index = v,
        );
        if (dLat == null) return null;
        lat += dLat;

        final dLng = _decodePolylineValue(
          encoded,
          refIndex: () => index,
          setIndex: (v) => index = v,
        );
        if (dLng == null) return null;
        lng += dLng;

        final latD = lat / factor;
        final lngD = lng / factor;
        if (latD.abs() > 90 || lngD.abs() > 180) return null;
        coords.add(LatLng(lat: latD, lng: lngD));
      }

      return coords.length >= 2 ? coords : null;
    } catch (_) {
      return null;
    }
  }

  static int? _decodePolylineValue(
    String encoded, {
    required int Function() refIndex,
    required void Function(int) setIndex,
  }) {
    int result = 0;
    int shift = 0;
    int index = refIndex();

    while (index < encoded.length) {
      final b = encoded.codeUnitAt(index) - 63;
      index++;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) {
        setIndex(index);
        final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        return delta;
      }
    }

    // Unterminated sequence.
    setIndex(index);
    return null;
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

  /// Builds GeoJSON for displaying routes.
  ///
  /// If the coordinate list contains large discontinuities, we split into a
  /// MultiLineString so Mapbox won't draw a long straight segment between
  /// disconnected parts.
  static String routeGeoJsonFromLatLngs(
    List<LatLng> coordinates, {
    double maxGapMeters = 1000.0,
  }) {
    if (coordinates.length < 2) {
      return jsonEncode({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': const <List<double>>[],
        },
        'properties': <String, dynamic>{},
      });
    }

    final segments = <List<LatLng>>[];
    var current = <LatLng>[coordinates.first];

    for (var i = 1; i < coordinates.length; i++) {
      final prev = coordinates[i - 1];
      final next = coordinates[i];
      final gap = _haversineMeters(prev, next);

      if (gap.isFinite && gap > maxGapMeters && current.length >= 2) {
        segments.add(current);
        current = <LatLng>[next];
        continue;
      }

      current.add(next);
    }

    if (current.length >= 2) {
      segments.add(current);
    }

    if (segments.isEmpty) {
      return lineStringGeoJsonFromLatLngs(<LatLng>[
        coordinates.first,
        coordinates.last,
      ]);
    }

    if (segments.length == 1) {
      return lineStringGeoJsonFromLatLngs(segments.first);
    }

    final multi = segments
        .map(
          (seg) =>
              seg.map((p) => <double>[p.lng, p.lat]).toList(growable: false),
        )
        .toList(growable: false);

    return jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'MultiLineString', 'coordinates': multi},
      'properties': <String, dynamic>{},
    });
  }

  /// Returns the maximum distance (meters) between consecutive points.
  static double maxConsecutiveGapMeters(List<LatLng> coordinates) {
    if (coordinates.length < 2) return 0.0;
    double maxGap = 0.0;
    for (var i = 1; i < coordinates.length; i++) {
      final d = _haversineMeters(coordinates[i - 1], coordinates[i]);
      if (d.isFinite && d > maxGap) {
        maxGap = d;
      }
    }
    return maxGap;
  }

  /// Returns the median distance (meters) between consecutive points.
  ///
  /// This is useful for detecting discontinuities as outliers relative to the
  /// typical sampling density of the route.
  static double medianConsecutiveGapMeters(List<LatLng> coordinates) {
    if (coordinates.length < 2) return 0.0;
    final gaps = <double>[];
    for (var i = 1; i < coordinates.length; i++) {
      final d = _haversineMeters(coordinates[i - 1], coordinates[i]);
      if (d.isFinite && d > 0) gaps.add(d);
    }
    if (gaps.isEmpty) return 0.0;
    gaps.sort();
    final mid = gaps.length ~/ 2;
    if (gaps.length.isOdd) return gaps[mid];
    return (gaps[mid - 1] + gaps[mid]) / 2.0;
  }

  /// Heuristic for whether a coordinate list is likely "broken".
  ///
  /// We consider a route broken when it contains a very large jump between
  /// consecutive points, or a single gap that is an extreme outlier compared
  /// to the typical gap in the same route.
  static bool isProbablyBroken(
    List<LatLng> coordinates, {
    double absoluteGapMeters = 15000.0,
    double minOutlierGapMeters = 3000.0,
    double outlierFactor = 30.0,
  }) {
    if (coordinates.length < 3) return true;
    final maxGap = maxConsecutiveGapMeters(coordinates);
    if (maxGap > absoluteGapMeters) return true;
    final medianGap = medianConsecutiveGapMeters(coordinates);
    if (medianGap <= 0) return false;
    if (maxGap > minOutlierGapMeters && (maxGap / medianGap) > outlierFactor) {
      return true;
    }
    return false;
  }

  /// Removes tiny artifacts like duplicates and immediate out-and-back spikes.
  ///
  /// This helps clean up occasional weird "hooks" near the destination when a
  /// backend returns a short detour that returns to almost the same point.
  static List<LatLng> cleanCoordinates(
    List<LatLng> coordinates, {
    double dedupeMeters = 1.0,
    double spikeReturnMeters = 6.0,
    double spikeMinLegMeters = 18.0,
  }) {
    if (coordinates.length < 2) return coordinates;

    // 1) Remove consecutive near-duplicates.
    final deduped = <LatLng>[coordinates.first];
    for (var i = 1; i < coordinates.length; i++) {
      final p = coordinates[i];
      final last = deduped.last;
      final d = _haversineMeters(last, p);
      if (!d.isFinite || d >= dedupeMeters) {
        deduped.add(p);
      }
    }
    if (deduped.length < 3) return deduped;

    // 2) Remove immediate out-and-back spikes: A -> B -> A (approximately).
    final out = <LatLng>[deduped.first];
    var i = 1;
    while (i < deduped.length - 1) {
      final a = out.last;
      final b = deduped[i];
      final c = deduped[i + 1];

      final dAC = _haversineMeters(a, c);
      final dAB = _haversineMeters(a, b);
      final dBC = _haversineMeters(b, c);

      final isSpike =
          dAC.isFinite &&
          dAB.isFinite &&
          dBC.isFinite &&
          dAC <= spikeReturnMeters &&
          dAB >= spikeMinLegMeters &&
          dBC >= spikeMinLegMeters;

      if (isSpike) {
        // Skip b, keep c by advancing.
        i++;
        continue;
      }

      out.add(b);
      i++;
    }
    out.add(deduped.last);

    return out.length >= 2 ? out : coordinates;
  }

  /// Ensures the coordinate list runs from [origin] to [destination].
  ///
  /// Some backends may return a LineString reversed (destination→origin).
  /// This helper chooses the orientation whose endpoints best match the
  /// provided origin/destination.
  static List<LatLng> orientOriginToDestination(
    List<LatLng> coordinates, {
    required LatLng origin,
    required LatLng destination,
  }) {
    if (coordinates.length < 2) return coordinates;

    final first = coordinates.first;
    final last = coordinates.last;

    final forwardScore =
        _haversineMeters(origin, first) + _haversineMeters(destination, last);
    final reversedScore =
        _haversineMeters(origin, last) + _haversineMeters(destination, first);

    if (reversedScore + 0.01 < forwardScore) {
      return coordinates.reversed.toList(growable: false);
    }
    return coordinates;
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;

    final lat1 = _degToRad(a.lat);
    final lat2 = _degToRad(b.lat);
    final dLat = lat2 - lat1;
    final dLon = _degToRad(b.lng - a.lng);

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLon = math.sin(dLon / 2.0);
    final aa =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    final c = 2.0 * math.atan2(math.sqrt(aa), math.sqrt(1.0 - aa));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
