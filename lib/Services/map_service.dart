import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Services/route_line_overlay_service.dart';

/// Service responsible for handling Mapbox-related behavior such as
/// initialization, realtime flood overlays, and style re-application.
class MapService {
  MapService();

  late final MapboxMap _mapboxMap;
  bool _initialized = false;

  static const _realtimeFloodSourceId = 'realtime-flood-source';
  static const _realtimeFloodFillLayerId1 = 'realtime-flood-layer-1';
  static const _realtimeFloodFillLayerId2 = 'realtime-flood-layer-2';
  static const _realtimeFloodFillLayerId3 = 'realtime-flood-layer-3';

  // Hosted vector tileset for realtime flood overlay.
  static const String _realtimeFloodTilesetUrl =
      'mapbox://johncarlo123.dryv_tileset_1';

  // The source layer inside the vector tileset.
  static const String _realtimeFloodSourceLayer = 'flooded';

  bool _realtimeFloodEnabled = false;
  LayerPosition? _realtimeFloodLayerPosition;

  MapboxMap get mapboxMap => _mapboxMap;

  bool get isInitialized => _initialized;

  /// Creates the internal reference to [MapboxMap] and performs any
  /// one-time configuration (such as disabling the scale bar).
  Future<void> attachMap(
    MapboxMap mapboxMap, {
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    _mapboxMap = mapboxMap;

    // pollInterval kept for backward compatibility, but the realtime flood
    // overlay is now backed by a hosted tileset (no polling needed).

    await _mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    _initialized = true;
  }

  /// Enables/disables realtime flood overlay and removes it when disabled.
  Future<void> setRealtimeFloodEnabled(
    bool enabled, {
    LayerPosition? layerPosition,
  }) async {
    if (!_initialized) return;

    _realtimeFloodLayerPosition = layerPosition;

    if (enabled) {
      _realtimeFloodEnabled = true;
      await _addRealtimeFloodTilesetLayer();
      return;
    }

    _realtimeFloodEnabled = false;
    await removeRealtimeFloodLayer();
  }

  Future<void> removeRealtimeFloodLayer() async {
    if (!_initialized) return;

    final style = _mapboxMap.style;

    const layerIds = <String>[
      _realtimeFloodFillLayerId1,
      _realtimeFloodFillLayerId2,
      _realtimeFloodFillLayerId3,
    ];

    for (final id in layerIds) {
      final exists = await style.styleLayerExists(id);
      if (exists) {
        try {
          await style.removeStyleLayer(id);
        } catch (_) {}
      }
    }

    final sourceExists = await style.styleSourceExists(_realtimeFloodSourceId);
    if (sourceExists) {
      try {
        await style.removeStyleSource(_realtimeFloodSourceId);
      } catch (_) {}
    }
  }

  /// Re-applies the realtime flood overlay. Intended to be called when the
  /// base style changes or other layers are toggled.
  Future<void> reapplyRealtimeFloodLayer() async {
    if (!_initialized) return;

    if (!_realtimeFloodEnabled) return;
    await _addRealtimeFloodTilesetLayer();
  }

  Future<LayerPosition?> _effectiveBaseLayerPosition(StyleManager style) async {
    // Prefer inserting below the route line layers so the route stays visible.
    LayerPosition? layerPosition = _realtimeFloodLayerPosition;
    if (layerPosition != null) return layerPosition;

    try {
      final hasRouteLayer = await style.styleLayerExists(
        RouteLineOverlayService.completedLayerId,
      );
      if (hasRouteLayer) {
        return LayerPosition(below: RouteLineOverlayService.completedLayerId);
      }
    } catch (_) {}

    return null;
  }

  Future<void> _addRealtimeFloodTilesetLayer() async {
    if (!_initialized) return;

    final style = _mapboxMap.style;

    // Ensure a clean slate.
    await removeRealtimeFloodLayer();

    await style.addSource(
      VectorSource(id: _realtimeFloodSourceId, url: _realtimeFloodTilesetUrl),
    );

    final basePosition = await _effectiveBaseLayerPosition(style);

    final fill1 = FillLayer(
      id: _realtimeFloodFillLayerId1,
      sourceId: _realtimeFloodSourceId,
      sourceLayer: _realtimeFloodSourceLayer,
      filter: [
        '==',
        ['get', 'risk_level'],
        1,
      ],
      fillColor: Colors.yellow.withValues(alpha: 0.6).toARGB32(),
    );

    if (basePosition != null) {
      await style.addLayerAt(fill1, basePosition);
    } else {
      await style.addLayer(fill1);
    }

    await style.addLayerAt(
      FillLayer(
        id: _realtimeFloodFillLayerId2,
        sourceId: _realtimeFloodSourceId,
        sourceLayer: _realtimeFloodSourceLayer,
        filter: [
          '==',
          ['get', 'risk_level'],
          2,
        ],
        fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: _realtimeFloodFillLayerId1),
    );

    await style.addLayerAt(
      FillLayer(
        id: _realtimeFloodFillLayerId3,
        sourceId: _realtimeFloodSourceId,
        sourceLayer: _realtimeFloodSourceLayer,
        filter: [
          '==',
          ['get', 'risk_level'],
          3,
        ],
        fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: _realtimeFloodFillLayerId2),
    );
  }

  void dispose() {
    _realtimeFloodEnabled = false;
  }
}
