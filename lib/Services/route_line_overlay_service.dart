import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Services/backend_route_geometry.dart';

class RouteLineOverlayService {
  static const String remainingSourceId = 'dryv-backend-route-remaining-source';
  static const String remainingLayerId = 'dryv-backend-route-remaining-layer';

  static const String completedSourceId = 'dryv-backend-route-completed-source';
  static const String completedLayerId = 'dryv-backend-route-completed-layer';

  static Future<LayerPosition?> _defaultRouteLayerPosition(
    StyleManager style,
  ) async {
    // Prefer inserting below an existing *base style* label layer.
    // This keeps the route above roads but below overlays like the puck/annotations.
    const baseLabelLayerCandidates = <String>[
      // Mapbox Streets / Standard commonly include these.
      'road-label',
      'poi-label',
      'transit-label',
      'place-label',
      'waterway-label',
      'settlement-label',
    ];

    for (final id in baseLabelLayerCandidates) {
      try {
        final exists = await style.styleLayerExists(id);
        if (exists) return LayerPosition(below: id);
      } catch (_) {}
    }

    // Fallback: try known overlay layers (location / annotations) when present.
    const overlayLayerCandidates = <String>[
      'mapbox-location-indicator-layer',
      'mapbox-location-indicator',
      'mapbox-location-shadow-layer',
      'mapbox-location-accuracy-layer',
      'mapbox-android-pointAnnotation-layer',
      'mapbox-android-annotation-layer',
      'mapbox-android-annotations-layer',
      'mapbox-annotation-layer',
    ];

    for (final id in overlayLayerCandidates) {
      try {
        final exists = await style.styleLayerExists(id);
        if (exists) return LayerPosition(below: id);
      } catch (_) {}
    }

    return null;
  }

  /// Draws the backend-approved route as a blue line.
  ///
  /// This uses a GeoJSON source + line layer to keep it fast and consistent.
  static Future<void> apply({
    required MapboxMap mapboxMap,
    required List<LatLng> coordinates,
    Color color = const Color(0xFF2F80ED),
    double width = 6.0,
  }) async {
    if (coordinates.length < 2) return;

    // Backwards compatible: apply only a remaining line.
    await applyWithProgress(
      mapboxMap: mapboxMap,
      completedCoordinates: const <LatLng>[],
      remainingCoordinates: coordinates,
      remainingColor: color,
      remainingWidth: width,
    );
  }

  /// Draw route with progress: completed portion (light blue) + remaining (blue).
  static Future<void> applyWithProgress({
    required MapboxMap mapboxMap,
    required List<LatLng> completedCoordinates,
    required List<LatLng> remainingCoordinates,
    Color completedColor = const Color(0xFF7FB3FF),
    double completedWidth = 6.0,
    double completedOpacity = 0.55,
    Color remainingColor = const Color(0xFF2F80ED),
    double remainingWidth = 6.0,
  }) async {
    final style = mapboxMap.style;
    final routeLayerPosition = await _defaultRouteLayerPosition(style);

    // Remove layers first (safe if they don't exist).
    for (final layerId in <String>[remainingLayerId, completedLayerId]) {
      final exists = await style.styleLayerExists(layerId);
      if (exists) {
        try {
          await style.removeStyleLayer(layerId);
        } catch (_) {}
      }
    }

    for (final sourceId in <String>[remainingSourceId, completedSourceId]) {
      final exists = await style.styleSourceExists(sourceId);
      if (exists) {
        try {
          await style.removeStyleSource(sourceId);
        } catch (_) {}
      }
    }

    final completedGeoJson = completedCoordinates.length >= 2
        ? BackendRouteGeometry.routeGeoJsonFromLatLngs(completedCoordinates)
        : BackendRouteGeometry.routeGeoJsonFromLatLngs(
            remainingCoordinates.length >= 2
                ? <LatLng>[
                    remainingCoordinates.first,
                    remainingCoordinates.first,
                  ]
                : const <LatLng>[],
          );

    final remainingGeoJson = remainingCoordinates.length >= 2
        ? BackendRouteGeometry.routeGeoJsonFromLatLngs(remainingCoordinates)
        : BackendRouteGeometry.routeGeoJsonFromLatLngs(
            completedCoordinates.length >= 2
                ? <LatLng>[completedCoordinates.last, completedCoordinates.last]
                : const <LatLng>[],
          );

    await style.addSource(
      GeoJsonSource(id: completedSourceId, data: completedGeoJson),
    );
    await style.addSource(
      GeoJsonSource(id: remainingSourceId, data: remainingGeoJson),
    );

    final completedLayer = LineLayer(
      id: completedLayerId,
      sourceId: completedSourceId,
      lineColor: completedColor.toARGB32(),
      lineWidth: completedWidth,
      lineOpacity: completedOpacity,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    );

    if (routeLayerPosition != null) {
      await style.addLayerAt(completedLayer, routeLayerPosition);
    } else {
      await style.addLayer(completedLayer);
    }

    final remainingLayer = LineLayer(
      id: remainingLayerId,
      sourceId: remainingSourceId,
      lineColor: remainingColor.toARGB32(),
      lineWidth: remainingWidth,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    );

    // Ensure the remaining line sits above the completed line.
    try {
      await style.addLayerAt(
        remainingLayer,
        LayerPosition(above: completedLayerId),
      );
    } catch (_) {
      if (routeLayerPosition != null) {
        await style.addLayerAt(remainingLayer, routeLayerPosition);
      } else {
        await style.addLayer(remainingLayer);
      }
    }
  }

  /// Update route progress without recreating layers/sources.
  /// Falls back to full re-apply if update fails.
  static Future<void> updateProgress({
    required MapboxMap mapboxMap,
    required List<LatLng> completedCoordinates,
    required List<LatLng> remainingCoordinates,
  }) async {
    final style = mapboxMap.style;

    final completedExists = await style.styleSourceExists(completedSourceId);
    final remainingExists = await style.styleSourceExists(remainingSourceId);
    if (!completedExists || !remainingExists) {
      await applyWithProgress(
        mapboxMap: mapboxMap,
        completedCoordinates: completedCoordinates,
        remainingCoordinates: remainingCoordinates,
      );
      return;
    }

    final completedGeoJson = completedCoordinates.length >= 2
        ? BackendRouteGeometry.routeGeoJsonFromLatLngs(completedCoordinates)
        : null;
    final remainingGeoJson = remainingCoordinates.length >= 2
        ? BackendRouteGeometry.routeGeoJsonFromLatLngs(remainingCoordinates)
        : null;

    try {
      if (completedGeoJson != null) {
        await style.setStyleSourceProperty(
          completedSourceId,
          'data',
          completedGeoJson,
        );
      }
      if (remainingGeoJson != null) {
        await style.setStyleSourceProperty(
          remainingSourceId,
          'data',
          remainingGeoJson,
        );
      }
    } catch (_) {
      await applyWithProgress(
        mapboxMap: mapboxMap,
        completedCoordinates: completedCoordinates,
        remainingCoordinates: remainingCoordinates,
      );
    }
  }

  static Future<void> remove({required MapboxMap mapboxMap}) async {
    final style = mapboxMap.style;

    for (final layerId in <String>[remainingLayerId, completedLayerId]) {
      final exists = await style.styleLayerExists(layerId);
      if (exists) {
        try {
          await style.removeStyleLayer(layerId);
        } catch (_) {}
      }
    }

    for (final sourceId in <String>[remainingSourceId, completedSourceId]) {
      final exists = await style.styleSourceExists(sourceId);
      if (exists) {
        try {
          await style.removeStyleSource(sourceId);
        } catch (_) {}
      }
    }
  }
}
