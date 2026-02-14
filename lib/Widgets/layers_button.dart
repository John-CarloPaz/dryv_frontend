import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class FloodOverlayVisibility {
  final bool floodMap;
  final bool realtimeFlood;

  const FloodOverlayVisibility({
    required this.floodMap,
    required this.realtimeFlood,
  });

  bool get any => floodMap || realtimeFlood;
}

class LayerButtonWidget extends StatefulWidget {
  final MapboxMap mapboxMap;
  final VoidCallback? onStyleChanged;
  final ValueChanged<FloodOverlayVisibility>? onFloodOverlayVisibilityChanged;
  const LayerButtonWidget({
    super.key,
    required this.mapboxMap,
    this.onStyleChanged,
    this.onFloodOverlayVisibilityChanged,
  });

  @override
  State<LayerButtonWidget> createState() => _LayerButtonWidgetState();
}

class _LayerButtonWidgetState extends State<LayerButtonWidget> {
  bool _isFloodLayerVisible = false;
  bool _isRealtimeFloodLayerVisible = false;

  void _notifyOverlayVisibility() {
    widget.onFloodOverlayVisibilityChanged?.call(
      FloodOverlayVisibility(
        floodMap: _isFloodLayerVisible,
        realtimeFlood: _isRealtimeFloodLayerVisible,
      ),
    );
  }

  bool _looksLikeLabelLayer(String id, String? type) {
    final t = (type ?? '').toLowerCase();
    if (t == 'symbol') return true;
    final lower = id.toLowerCase();
    return lower.contains('label') ||
        lower.contains('poi') ||
        lower.contains('place') ||
        lower.contains('settlement');
  }

  bool _looksLikeLocationLayer(String id) {
    final lower = id.toLowerCase();
    return lower.contains('location') ||
        lower.contains('puck') ||
        lower.contains('mapbox-location');
  }

  Future<String?> _findOverlayAnchorLayerId() async {
    // We want flood overlays below map labels/POIs and below the location puck.
    // On classic styles (streets/satellite-streets), `slot` is ignored, so we
    // must insert layers explicitly using LayerPosition.
    final layers = await widget.mapboxMap.style.getStyleLayers();

    int? firstLabelIndex;
    int? firstLocationIndex;

    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i] as dynamic;
      final id = (layer.id as String?) ?? '';
      if (id.isEmpty) continue;

      final type = layer.type as String?;

      if (firstLabelIndex == null && _looksLikeLabelLayer(id, type)) {
        firstLabelIndex = i;
      }
      if (firstLocationIndex == null && _looksLikeLocationLayer(id)) {
        firstLocationIndex = i;
      }

      if (firstLabelIndex != null && firstLocationIndex != null) break;
    }

    int? anchorIndex;
    if (firstLabelIndex != null && firstLocationIndex != null) {
      anchorIndex = firstLabelIndex < firstLocationIndex
          ? firstLabelIndex
          : firstLocationIndex;
    } else {
      anchorIndex = firstLabelIndex ?? firstLocationIndex;
    }

    if (anchorIndex == null) return null;
    final anchor = layers[anchorIndex] as dynamic;
    return anchor.id as String?;
  }

  Future<LayerPosition?> _overlayBaseLayerPosition() async {
    final anchorId = await _findOverlayAnchorLayerId();
    if (anchorId == null || anchorId.isEmpty) return null;
    return LayerPosition(below: anchorId);
  }

  void _showMutualExclusionSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLayerDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final floodDisabled = _isRealtimeFloodLayerVisible;
        final realtimeDisabled = _isFloodLayerVisible;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map Layers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Mapbox Streets'),
                onTap: () {
                  _changeMapStyle('mapbox://styles/mapbox/streets-v12');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.terrain),
                title: const Text('Satellite View'),
                onTap: () {
                  _changeMapStyle(
                    'mapbox://styles/mapbox/satellite-streets-v12',
                  );
                  Navigator.pop(context);
                },
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.water,
                  color: floodDisabled ? Colors.grey : null,
                ),
                title: const Text('Flood Map Layer'),
                subtitle: floodDisabled
                    ? const Text('Turn off Realtime Flood Layer to enable')
                    : null,
                value: _isFloodLayerVisible,
                onChanged: floodDisabled
                    ? null
                    : (value) async {
                        await _toggleFloodLayer();
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.waves,
                  color: realtimeDisabled ? Colors.grey : null,
                ),
                title: const Text('Realtime Flood Layer'),
                subtitle: realtimeDisabled
                    ? const Text('Turn off Flood Map Layer to enable')
                    : null,
                value: _isRealtimeFloodLayerVisible,
                onChanged: realtimeDisabled
                    ? null
                    : (value) async {
                        await _toggleRealtimeFloodLayer();
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
  }

  Future<void> _changeMapStyle(String styleUrl) async {
    await widget.mapboxMap.style.setStyleURI(styleUrl);
    // Notify parent so it can re-apply sources/layers that were removed by style change
    widget.onStyleChanged?.call();

    // Re-apply any overlays that were enabled prior to the style change.
    // Style changes reset runtime-added sources/layers.
    await _reapplyEnabledOverlays();
  }

  Future<void> _reapplyEnabledOverlays() async {
    // Enforce mutual exclusivity (defensive: older builds may have allowed both).
    if (_isFloodLayerVisible && _isRealtimeFloodLayerVisible) {
      setState(() => _isRealtimeFloodLayerVisible = false);
      _notifyOverlayVisibility();
    }
    if (_isFloodLayerVisible) {
      await _addFloodLayer();
    }
    if (_isRealtimeFloodLayerVisible) {
      await _addRealtimeFloodLayer();
    }
  }

  Future<void> _removeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;
    for (final id in [
      'flood-layer-var1',
      'flood-layer-var2',
      'flood-layer-var3',
    ]) {
      final exists = await mapboxMap.style.styleLayerExists(id);
      if (exists) await mapboxMap.style.removeStyleLayer(id);
    }

    final sourceExists = await mapboxMap.style.styleSourceExists(
      'flood_source',
    );
    if (sourceExists) await mapboxMap.style.removeStyleSource('flood_source');
  }

  Future<void> _addFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    // Ensure no stale source/layers exist.
    await _removeFloodLayer();

    // Hosted vector tileset for Pampanga flood map
    await mapboxMap.style.addSource(
      VectorSource(
        id: 'flood_source',
        url: 'mapbox://johncarlo123.pampanga-flood-map',
      ),
    );

    final basePosition = await _overlayBaseLayerPosition();

    // Categorized layers by `Var` property (note uppercase V)
    final floodVar1 = FillLayer(
      id: 'flood-layer-var1',
      sourceId: 'flood_source',
      sourceLayer: 'flood',
      filter: [
        '==',
        ['get', 'Var'],
        1,
      ],
      fillColor: Colors.yellow.withValues(alpha: .6).toARGB32(),
    );
    if (basePosition != null) {
      await mapboxMap.style.addLayerAt(floodVar1, basePosition);
    } else {
      await mapboxMap.style.addLayer(floodVar1);
    }

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: 'flood-layer-var2',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: [
          '==',
          ['get', 'Var'],
          2,
        ],
        fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: 'flood-layer-var1'),
    );

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: 'flood-layer-var3',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: [
          '==',
          ['get', 'Var'],
          3,
        ],
        fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: 'flood-layer-var2'),
    );
  }

  Future<void> _toggleFloodLayer() async {
    if (_isFloodLayerVisible) {
      await _removeFloodLayer();

      setState(() => _isFloodLayerVisible = false);
      _notifyOverlayVisibility();
      // notify parent to re-apply overlays if needed
      widget.onStyleChanged?.call();
    } else {
      if (_isRealtimeFloodLayerVisible) {
        _showMutualExclusionSnackBar(
          'Turn off Realtime Flood Layer before enabling Flood Map Layer.',
        );
        return;
      }
      try {
        await _addFloodLayer();

        setState(() => _isFloodLayerVisible = true);
        _notifyOverlayVisibility();
        debugPrint('✅ Flood tileset layer loaded (Pampanga).');
      } catch (e, st) {
        debugPrint('❌ Failed to load flood tileset layer: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add flood tileset layer')),
        );
      }
    }
  }

  Future<void> _toggleRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const outlineLayerId = 'realtime-flood-outline';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';
    final fillLayerIds = [fillLayerId1, fillLayerId2, fillLayerId3];

    if (_isRealtimeFloodLayerVisible) {
      // Remove realtime flood layers + source
      for (final id in [...fillLayerIds, outlineLayerId]) {
        final exists = await mapboxMap.style.styleLayerExists(id);
        if (exists) await mapboxMap.style.removeStyleLayer(id);
      }

      final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
      if (sourceExists) await mapboxMap.style.removeStyleSource(sourceId);

      setState(() => _isRealtimeFloodLayerVisible = false);
      _notifyOverlayVisibility();
      widget.onStyleChanged?.call();
      return;
    }

    if (_isFloodLayerVisible) {
      _showMutualExclusionSnackBar(
        'Turn off Flood Map Layer before enabling Realtime Flood Layer.',
      );
      return;
    }

    try {
      await _addRealtimeFloodLayer();
      setState(() => _isRealtimeFloodLayerVisible = true);
      _notifyOverlayVisibility();
      debugPrint('✅ Realtime flood layer loaded from dryv_b.');
      widget.onStyleChanged?.call();
    } catch (ePrimary, stPrimary) {
      debugPrint(
        '❌ Failed to load realtime dryv_b tileset: $ePrimary\n$stPrimary',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add realtime flood layer')),
      );
    }
  }

  Future<void> _removeRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const outlineLayerId = 'realtime-flood-outline';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';
    final fillLayerIds = [fillLayerId1, fillLayerId2, fillLayerId3];

    for (final id in [...fillLayerIds, outlineLayerId]) {
      final exists = await mapboxMap.style.styleLayerExists(id);
      if (exists) await mapboxMap.style.removeStyleLayer(id);
    }

    final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
    if (sourceExists) await mapboxMap.style.removeStyleSource(sourceId);
  }

  Future<void> _addRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const outlineLayerId = 'realtime-flood-outline';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';

    // Use hosted vector tileset for realtime flood view.
    const primaryTilesetUrl = 'mapbox://johncarlo123.dryv';

    await _removeRealtimeFloodLayer();

    await mapboxMap.style.addSource(
      VectorSource(id: sourceId, url: primaryTilesetUrl),
    );

    final basePosition = await _overlayBaseLayerPosition();

    final realtimeFill1 = FillLayer(
      id: fillLayerId1,
      sourceId: sourceId,
      sourceLayer: 'flooded',
      filter: [
        '==',
        ['get', 'risk_level'],
        1,
      ],
      fillColor: Colors.lightBlue.withValues(alpha: 0.6).toARGB32(),
    );
    if (basePosition != null) {
      await mapboxMap.style.addLayerAt(realtimeFill1, basePosition);
    } else {
      await mapboxMap.style.addLayer(realtimeFill1);
    }

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: fillLayerId2,
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: [
          '==',
          ['get', 'risk_level'],
          2,
        ],
        fillColor: Colors.blue.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: fillLayerId1),
    );

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: fillLayerId3,
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: [
          '==',
          ['get', 'risk_level'],
          3,
        ],
        fillColor: Colors.blue.withValues(alpha: 0.9).toARGB32(),
      ),
      LayerPosition(above: fillLayerId2),
    );

    await mapboxMap.style.addLayerAt(
      LineLayer(
        id: outlineLayerId,
        sourceId: sourceId,
        sourceLayer: 'flooded',
        lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
        lineWidth: 1.0,
      ),
      LayerPosition(above: fillLayerId3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.white,
      mini: true,
      elevation: 2,
      onPressed: () => _showLayerDrawer(context),
      child: const Icon(Icons.layers, color: Colors.grey),
    );
  }
}
