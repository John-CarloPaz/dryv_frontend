import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Services/route_line_overlay_service.dart';

/// Service responsible for handling Mapbox-related behavior such as
/// initialization, realtime flood overlays, and style re-application.
class MapService {
  MapService();

  late final MapboxMap _mapboxMap;
  bool _initialized = false;

  Timer? _floodTimer;
  Duration floodPollInterval = const Duration(seconds: 2);
  String? _lastFloodGeoJson;
  DateTime? _lastFloodUpdated;

  static const _realtimeFloodSourceId = 'realtime-flood-source';
  static const _realtimeFloodLayerId = 'realtime-flood-layer';
  static const _realtimeFloodOutlineLayerId = 'realtime-flood-outline';

  bool _realtimeFloodEnabled = false;
  LayerPosition? _realtimeFloodLayerPosition;

  /// Fake API endpoint that returns GeoJSON for flooded polygons.
  static const String _realtimeFloodUrl =
      'https://raw.githubusercontent.com/John-CarloPaz/fake-apis/main/flooded-polygons.json';

  /// Optional callbacks to let the UI react to flood updates.
  final ValueNotifier<DateTime?> floodLastUpdatedNotifier =
      ValueNotifier<DateTime?>(null);

  MapboxMap get mapboxMap => _mapboxMap;

  bool get isInitialized => _initialized;

  String? get lastFloodGeoJson => _lastFloodGeoJson;

  DateTime? get lastFloodUpdated => _lastFloodUpdated;

  /// Creates the internal reference to [MapboxMap] and performs any
  /// one-time configuration (such as disabling the scale bar).
  Future<void> attachMap(
    MapboxMap mapboxMap, {
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    _mapboxMap = mapboxMap;
    floodPollInterval = pollInterval;

    await _mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    _initialized = true;
  }

  /// Starts periodic polling of the realtime flood API and applying the
  /// resulting GeoJSON to the map.
  void startRealtimeFloodUpdates() {
    if (!_initialized) return;

    _realtimeFloodEnabled = true;

    _floodTimer?.cancel();
    _fetchAndApplyRealtimeFloodData();
    _floodTimer = Timer.periodic(
      floodPollInterval,
      (_) => _fetchAndApplyRealtimeFloodData(),
    );
  }

  /// Stops realtime flood polling. Call from the widget's dispose.
  void stopRealtimeFloodUpdates() {
    _realtimeFloodEnabled = false;
    _floodTimer?.cancel();
  }

  /// Enables/disables realtime flood overlay and removes it when disabled.
  Future<void> setRealtimeFloodEnabled(
    bool enabled, {
    LayerPosition? layerPosition,
  }) async {
    if (!_initialized) return;

    _realtimeFloodLayerPosition = layerPosition;

    if (enabled) {
      startRealtimeFloodUpdates();
      return;
    }

    stopRealtimeFloodUpdates();
    await removeRealtimeFloodLayer();
  }

  Future<void> removeRealtimeFloodLayer() async {
    if (!_initialized) return;

    final style = _mapboxMap.style;

    const layerIds = <String>[
      _realtimeFloodLayerId,
      _realtimeFloodOutlineLayerId,
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

    if (_lastFloodGeoJson != null) {
      await _applyFloodDataToMap(_lastFloodGeoJson!);
    } else {
      await _fetchAndApplyRealtimeFloodData();
    }
  }

  /// Internal: fetches flood data from the API and updates the map overlay.
  Future<void> _fetchAndApplyRealtimeFloodData() async {
    if (!_initialized) return;
    if (!_realtimeFloodEnabled) return;

    debugPrint('${DateTime.now()} Fetching realtime flood data...');

    try {
      final fetchUrl =
          '$_realtimeFloodUrl?_ts=${DateTime.now().millisecondsSinceEpoch}';
      final resp = await http.get(Uri.parse(fetchUrl));

      if (resp.statusCode != 200) {
        debugPrint('Realtime flood API returned ${resp.statusCode}');
        return;
      }

      final geojson = resp.body;

      // Avoid unnecessary updates when payload didn't change
      if (_lastFloodGeoJson != null && _lastFloodGeoJson == geojson) return;

      await _applyFloodDataToMap(geojson);

      _lastFloodGeoJson = geojson;
      _lastFloodUpdated = DateTime.now();
      floodLastUpdatedNotifier.value = _lastFloodUpdated;

      debugPrint('Realtime flood source updated at $_lastFloodUpdated');
    } catch (e, st) {
      debugPrint('Failed to load realtime flood data: $e\n$st');
    }
  }

  /// Applies flood GeoJSON data to the map by creating/updating the source
  /// and layers.
  Future<void> _applyFloodDataToMap(String geojson) async {
    if (!_initialized) return;

    try {
      final style = _mapboxMap.style;

      // Prefer inserting below the route line layers so the route stays visible.
      LayerPosition? layerPosition = _realtimeFloodLayerPosition;
      if (layerPosition == null) {
        try {
          final hasRouteLayer = await style.styleLayerExists(
            RouteLineOverlayService.completedLayerId,
          );
          if (hasRouteLayer) {
            layerPosition = LayerPosition(
              below: RouteLineOverlayService.completedLayerId,
            );
          }
        } catch (_) {
          layerPosition = null;
        }
      }

      // Update existing source data in-place when possible (less flicker).
      final sourceExists = await style.styleSourceExists(_realtimeFloodSourceId);
      if (sourceExists) {
        try {
          await style.setStyleSourceProperty(
            _realtimeFloodSourceId,
            'data',
            geojson,
          );
        } catch (_) {
          // Fall back to recreate.
          try {
            await style.removeStyleSource(_realtimeFloodSourceId);
          } catch (_) {}
          await style.addSource(
            GeoJsonSource(id: _realtimeFloodSourceId, data: geojson),
          );
        }
      } else {
        await style.addSource(
          GeoJsonSource(id: _realtimeFloodSourceId, data: geojson),
        );
      }

      // Ensure layers exist.
      final fillExists = await style.styleLayerExists(_realtimeFloodLayerId);
      final outlineExists = await style.styleLayerExists(
        _realtimeFloodOutlineLayerId,
      );

      if (fillExists) {
        // Leave as-is.
      } else {
        final layer = FillLayer(
          id: _realtimeFloodLayerId,
          sourceId: _realtimeFloodSourceId,
          fillColor: Colors.cyan.withValues(alpha: 0.35).toARGB32(),
        );
        if (layerPosition != null) {
          await style.addLayerAt(layer, layerPosition);
        } else {
          await style.addLayer(layer);
        }
      }

      if (outlineExists) {
        // Leave as-is.
      } else {
        final layer = LineLayer(
          id: _realtimeFloodOutlineLayerId,
          sourceId: _realtimeFloodSourceId,
          lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
          lineWidth: 1.0,
        );
        if (layerPosition != null) {
          await style.addLayerAt(layer, layerPosition);
        } else {
          await style.addLayer(layer);
        }
      }

      debugPrint(
        'Realtime flood layer applied successfully at ${DateTime.now()}',
      );
    } catch (e, st) {
      debugPrint('Failed to apply realtime flood data to map: $e\n$st');
    }
  }

  void dispose() {
    stopRealtimeFloodUpdates();
    floodLastUpdatedNotifier.dispose();
  }
}
