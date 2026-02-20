import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Services/backend_route_geometry.dart';

void main() {
  test('extracts coordinates from GeoJSON LineString', () {
    final geoJson = {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [120.0, 14.0],
          [120.001, 14.001],
          [120.002, 14.002],
        ],
      },
      'properties': {},
    };

    final coords = BackendRouteGeometry.tryExtractLineStringCoordinates(
      geoJson,
    );
    expect(coords, isNotNull);
    expect(coords!.length, 3);
    expect(coords.first.lat, closeTo(14.0, 1e-12));
    expect(coords.first.lng, closeTo(120.0, 1e-12));
  });

  test('extracts coordinates when passed full backend payload wrapper', () {
    final payload = {
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [120.0, 14.0],
              [120.001, 14.001],
              [120.002, 14.002],
            ],
          },
        },
      ],
      'waypoints': [
        {
          'location': [120.0, 14.0],
        },
        {
          'location': [120.002, 14.002],
        },
      ],
    };

    final coords = BackendRouteGeometry.tryExtractLineStringCoordinates(
      payload,
    );
    expect(coords, isNotNull);
    expect(coords!.length, 3);
  });

  test('extracts coordinates from stepsJson geometry fallback', () {
    final steps = <Map<String, dynamic>>[
      {
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [120.0, 14.0],
            [120.001, 14.001],
          ],
        },
      },
      {
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [120.001, 14.001],
            [120.002, 14.002],
          ],
        },
      },
    ];

    final coords = BackendRouteGeometry.tryExtractFromStepsJson(steps);
    expect(coords, isNotNull);
    expect(coords!.length, 3);
  });

  test('extracts coordinates from encoded polyline (precision 5)', () {
    // Standard reference polyline example from Google Polyline Algorithm docs.
    // Points: (38.5,-120.2) (40.7,-120.95) (43.252,-126.453)
    const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

    final coords = BackendRouteGeometry.tryExtractLineStringCoordinates(
      encoded,
    );
    expect(coords, isNotNull);
    expect(coords!.length, 3);

    expect(coords[0].lat, closeTo(38.5, 1e-5));
    expect(coords[0].lng, closeTo(-120.2, 1e-5));
    expect(coords[2].lat, closeTo(43.252, 1e-5));
    expect(coords[2].lng, closeTo(-126.453, 1e-5));
  });

  test('returns null for invalid geometry payloads', () {
    expect(BackendRouteGeometry.tryExtractLineStringCoordinates(null), isNull);
    expect(BackendRouteGeometry.tryExtractLineStringCoordinates(''), isNull);
    expect(
      BackendRouteGeometry.tryExtractLineStringCoordinates({'foo': 'bar'}),
      isNull,
    );
  });

  test('can extract from raw coordinates array', () {
    final coords = BackendRouteGeometry.tryExtractLineStringCoordinates([
      [120.0, 14.0],
      [120.01, 14.01],
    ]);

    expect(coords, isNotNull);
    expect(coords!.length, 2);
    expect(coords[0].lat, closeTo(14.0, 1e-12));
    expect(coords[0].lng, closeTo(120.0, 1e-12));
    expect(coords[1].lat, closeTo(14.01, 1e-12));
    expect(coords[1].lng, closeTo(120.01, 1e-12));
  });

  test(
    'routeGeoJsonFromLatLngs splits into MultiLineString for large gaps',
    () {
      final coords = [
        // Segment A
        const LatLng(lat: 14.0, lng: 120.0),
        const LatLng(lat: 14.0001, lng: 120.0001),
        // Big jump (different city)
        const LatLng(lat: 15.0, lng: 121.0),
        const LatLng(lat: 15.0001, lng: 121.0001),
      ];

      final geo = BackendRouteGeometry.routeGeoJsonFromLatLngs(
        coords,
        maxGapMeters: 5000,
      );

      final obj = jsonDecode(geo) as Map<String, dynamic>;
      final geom = obj['geometry'] as Map<String, dynamic>;
      expect(geom['type'], 'MultiLineString');
      final multi = geom['coordinates'] as List<dynamic>;
      expect(multi.length, 2);
    },
  );

  test('cleanCoordinates removes immediate out-and-back spike', () {
    // A -> B -> ~A -> C. The B point should be removed.
    final coords = <LatLng>[
      const LatLng(lat: 14.0, lng: 120.0),
      const LatLng(lat: 14.0003, lng: 120.0003),
      const LatLng(lat: 14.0, lng: 120.0),
      const LatLng(lat: 14.001, lng: 120.001),
    ];

    final cleaned = BackendRouteGeometry.cleanCoordinates(
      coords,
      dedupeMeters: 0.5,
      spikeReturnMeters: 5.0,
      spikeMinLegMeters: 20.0,
    );

    expect(cleaned.length, lessThan(coords.length));
    // Ensure the second point is no longer the spike point.
    expect(cleaned[1].lat, isNot(closeTo(14.0003, 1e-9)));
  });

  test('isProbablyBroken detects an extreme discontinuity outlier', () {
    final coords = <LatLng>[
      const LatLng(lat: 14.0, lng: 120.0),
      const LatLng(lat: 14.00001, lng: 120.00001),
      const LatLng(lat: 14.00002, lng: 120.00002),
      // Massive jump.
      const LatLng(lat: 15.0, lng: 121.0),
      const LatLng(lat: 15.00001, lng: 121.00001),
    ];

    expect(
      BackendRouteGeometry.isProbablyBroken(
        coords,
        absoluteGapMeters: 10000,
        minOutlierGapMeters: 1000,
        outlierFactor: 10,
      ),
      isTrue,
    );
  });
}
