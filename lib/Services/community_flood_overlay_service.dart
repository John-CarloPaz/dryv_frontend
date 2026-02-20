import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Models/community_flooded_roads.dart';
import 'package:dryvmobapp/Services/community_flooded_roads_service.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class CommunityFloodOverlayService {
  static const String sourceId = 'dryv-community-flooded-roads-source';
  static const String _labelLayerId = 'dryv-community-flooded-roads-label';

  static const List<int> _riskLevels = <int>[0, 1, 2, 3];

  bool _enabled = false;
  CommunityFloodedRoadsResponse? _cached;
  DateTime? _cachedAt;

  static const Duration _defaultCacheMaxAge = Duration(minutes: 5);

  bool get isEnabled => _enabled;

  bool _isCacheFresh([Duration maxAge = _defaultCacheMaxAge]) {
    final at = _cachedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <= maxAge;
  }

  Future<void> warmCache({
    int minRiskLevel = 0,
    Duration maxAge = _defaultCacheMaxAge,
  }) async {
    // Best-effort prefetch to avoid UX delays on first toggle.
    if (_cached != null && _isCacheFresh(maxAge)) return;
    try {
      _cached = await CommunityFloodedRoadsService().fetchFloodedRoads(
        minRiskLevel: minRiskLevel,
      );
      _cachedAt = DateTime.now();
    } catch (_) {
      // Ignore warm-up failures; user-initiated toggle will surface errors.
    }
  }

  List<String> get _circleLayerIds => _riskLevels
      .map((r) => 'dryv-community-flooded-roads-circle-$r')
      .toList(growable: false);

  Future<void> setEnabled({
    required MapboxMap mapboxMap,
    required bool enabled,
    LayerPosition? layerPosition,
    int minRiskLevel = 0,
    Duration cacheMaxAge = _defaultCacheMaxAge,
  }) async {
    if (!enabled) {
      _enabled = false;
      await remove(mapboxMap: mapboxMap);
      return;
    }

    try {
      // Fast path: apply cached data immediately when available.
      final hasCache = _cached != null;
      if (!hasCache) {
        _cached = await CommunityFloodedRoadsService().fetchFloodedRoads(
          minRiskLevel: minRiskLevel,
        );
        _cachedAt = DateTime.now();
      }

      final resp = _cached!;

      await _apply(
        mapboxMap: mapboxMap,
        response: resp,
        layerPosition: layerPosition,
      );

      _enabled = true;

      // If cache is stale, refresh in the background so the user sees something
      // immediately, then gets updated points a moment later.
      if (!_isCacheFresh(cacheMaxAge)) {
        Future(() async {
          try {
            await refresh(
              mapboxMap: mapboxMap,
              layerPosition: layerPosition,
              minRiskLevel: minRiskLevel,
            );
          } catch (_) {
            // Ignore refresh failures.
          }
        });
      }
    } catch (_) {
      _enabled = false;
      rethrow;
    }
  }

  Future<void> refresh({
    required MapboxMap mapboxMap,
    LayerPosition? layerPosition,
    int minRiskLevel = 0,
  }) async {
    if (!_enabled) return;

    _cached = await CommunityFloodedRoadsService().fetchFloodedRoads(
      minRiskLevel: minRiskLevel,
    );
    _cachedAt = DateTime.now();

    final style = mapboxMap.style;
    final sourceExists = await style.styleSourceExists(sourceId);
    if (sourceExists) {
      try {
        await style.setStyleSourceProperty(
          sourceId,
          'data',
          _geoJson(_cached!),
        );
        return;
      } catch (_) {
        // fallthrough to full re-apply
      }
    }

    await _apply(
      mapboxMap: mapboxMap,
      response: _cached!,
      layerPosition: layerPosition,
    );
  }

  Future<void> reapplyIfEnabled({
    required MapboxMap mapboxMap,
    LayerPosition? layerPosition,
  }) async {
    if (!_enabled) return;
    final resp = _cached;
    if (resp == null) {
      await setEnabled(
        mapboxMap: mapboxMap,
        enabled: true,
        layerPosition: layerPosition,
      );
      return;
    }

    await _apply(
      mapboxMap: mapboxMap,
      response: resp,
      layerPosition: layerPosition,
    );
  }

  Future<void> remove({required MapboxMap mapboxMap}) async {
    final style = mapboxMap.style;

    final allLayerIds = <String>[..._circleLayerIds, _labelLayerId];
    for (final id in allLayerIds) {
      try {
        final exists = await style.styleLayerExists(id);
        if (exists) await style.removeStyleLayer(id);
      } catch (_) {}
    }

    try {
      final sourceExists = await style.styleSourceExists(sourceId);
      if (sourceExists) await style.removeStyleSource(sourceId);
    } catch (_) {}
  }

  Future<void> _apply({
    required MapboxMap mapboxMap,
    required CommunityFloodedRoadsResponse response,
    LayerPosition? layerPosition,
  }) async {
    final style = mapboxMap.style;

    await remove(mapboxMap: mapboxMap);

    await style.addSource(
      GeoJsonSource(id: sourceId, data: _geoJson(response)),
    );

    final basePosition = layerPosition;

    for (final risk in _riskLevels) {
      final layer = CircleLayer(
        id: 'dryv-community-flooded-roads-circle-$risk',
        sourceId: sourceId,
        filter: [
          '==',
          ['get', 'risk_level'],
          risk,
        ],
        circleRadius: 6.0,
        circleOpacity: 0.92,
        circleColor: _riskColor(risk).toARGB32(),
        circleStrokeColor: Colors.white.withValues(alpha: 0.92).toARGB32(),
        circleStrokeWidth: 2.0,
      );

      if (risk == _riskLevels.first) {
        if (basePosition != null) {
          await style.addLayerAt(layer, basePosition);
        } else {
          await style.addLayer(layer);
        }
      } else {
        await style.addLayerAt(
          layer,
          LayerPosition(
            above: 'dryv-community-flooded-roads-circle-${risk - 1}',
          ),
        );
      }
    }

    final labelLayer = SymbolLayer(
      id: _labelLayerId,
      sourceId: sourceId,
      // Token replacement is supported by Mapbox style spec and keeps this
      // compatible with the strongly-typed mapbox_maps_flutter layer API.
      textField: '{label}',
      textSize: 12.0,
      textAnchor: TextAnchor.TOP,
      textOffset: [0.0, 1.2],
      textAllowOverlap: false,
      textIgnorePlacement: false,
      textHaloColor: Colors.white.withValues(alpha: 0.92).toARGB32(),
      textHaloWidth: 1.6,
      textColor: AppColors.primary.toARGB32(),
      // Show details only when zoomed in.
      minZoom: 14.8,
    );

    await style.addLayerAt(
      labelLayer,
      LayerPosition(above: _circleLayerIds.last),
    );
  }

  String _geoJson(CommunityFloodedRoadsResponse resp) {
    final features = resp.floodedRoads
        .where((r) => r.lat != 0.0 && r.lng != 0.0)
        .map((r) {
          final roadName = (r.road.name.trim().isEmpty)
              ? 'Flooded road'
              : r.road.name.trim();
          final depth = r.chi.avgEstimatedDepthLabel.trim();
          final reports = r.chi.reportsCount;
          final depthPart = depth.isEmpty ? '' : depth;
          final reportPart = reports <= 0
              ? ''
              : '$reports ${reports == 1 ? 'report' : 'reports'}';

          String label = roadName;
          final parts = <String>[];
          if (depthPart.isNotEmpty) parts.add(depthPart);
          if (reportPart.isNotEmpty) parts.add(reportPart);
          if (parts.isNotEmpty) {
            // Keep labels single-line to avoid platform/style rendering quirks
            // that can occur with multi-line text on some Mapbox builds.
            label = '$roadName • ${parts.join(' • ')}';
          }

          return {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [r.lng, r.lat],
            },
            'properties': {
              'risk_level': r.chi.riskLevel,
              'reports_count': r.chi.reportsCount,
              'depth_label': r.chi.avgEstimatedDepthLabel,
              'road_name': r.road.name,
              'label': label,
            },
          };
        })
        .toList(growable: false);

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Color _riskColor(int riskLevel) {
    if (riskLevel <= 0) return AppColors.accent;
    if (riskLevel == 1) return const Color(0xFFF1C40F);
    if (riskLevel == 2) return const Color(0xFFFF8C00);
    return const Color(0xFFE74C3C);
  }

  void dispose() {
    _enabled = false;
    _cached = null;
    _cachedAt = null;
  }
}
