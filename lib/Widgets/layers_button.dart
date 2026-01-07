import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LayerButtonWidget extends StatefulWidget {
  final MapboxMap mapboxMap;
  final VoidCallback? onStyleChanged;
  const LayerButtonWidget({super.key, required this.mapboxMap, this.onStyleChanged});

  @override
  State<LayerButtonWidget> createState() => _LayerButtonWidgetState();
}

class _LayerButtonWidgetState extends State<LayerButtonWidget> {
  bool _isFloodLayerVisible = false;
  bool _isRealtimeFloodLayerVisible = false;

  void _showLayerDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  _changeMapStyle('mapbox://styles/mapbox/satellite-streets-v12');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.water),
                title: const Text('Flood Map Layer'),
                onTap: () {
                  _toggleFloodLayer();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.waves),
                title: const Text('Realtime Flood Layer'),
                onTap: () {
                  _toggleRealtimeFloodLayer();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
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

    final sourceExists = await mapboxMap.style.styleSourceExists('flood_source');
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

    // Categorized layers by `Var` property (note uppercase V)
    await mapboxMap.style.addLayer(
      FillLayer(
        id: 'flood-layer-var1',
        slot: 'top',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: ['==', ['get', 'Var'], 1],
        fillColor: Colors.yellow.withValues(alpha: .6).toARGB32(),
      ),
    );

    await mapboxMap.style.addLayer(
      FillLayer(
        id: 'flood-layer-var2',
        slot: 'top',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: ['==', ['get', 'Var'], 2],
        fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
      ),
    );

    await mapboxMap.style.addLayer(
      FillLayer(
        id: 'flood-layer-var3',
        slot: 'top',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: ['==', ['get', 'Var'], 3],
        fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
      ),
    );
  }

  Future<void> _toggleFloodLayer() async {
    if (_isFloodLayerVisible) {
      await _removeFloodLayer();

      setState(() => _isFloodLayerVisible = false);
      // notify parent to re-apply overlays if needed
      widget.onStyleChanged?.call();
    } else {
      try {
        await _addFloodLayer();

        setState(() => _isFloodLayerVisible = true);
        debugPrint('✅ Flood tileset layer loaded (Pampanga).');
      } catch (e, st) {
        debugPrint('❌ Failed to load flood tileset layer: $e\n$st');
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
      widget.onStyleChanged?.call();
      return;
    }

    try {
      await _addRealtimeFloodLayer();
      setState(() => _isRealtimeFloodLayerVisible = true);
      debugPrint('✅ Realtime flood layer loaded from dryv_b.');
      widget.onStyleChanged?.call();
    } catch (ePrimary, stPrimary) {
      debugPrint('❌ Failed to load realtime dryv_b tileset: $ePrimary\n$stPrimary');
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
      VectorSource(
        id: sourceId,
        url: primaryTilesetUrl,
      ),
    );

    await mapboxMap.style.addLayer(
      FillLayer(
        id: fillLayerId1,
        slot: 'top',
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: ['==', ['get', 'risk_level'], 1],
        fillColor: Colors.lightBlue.withValues(alpha: 0.6).toARGB32(),
      ),
    );

    await mapboxMap.style.addLayer(
      FillLayer(
        id: fillLayerId2,
        slot: 'top',
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: ['==', ['get', 'risk_level'], 2],
        fillColor: Colors.blue.withValues(alpha: 0.6).toARGB32(),
      ),
    );

    await mapboxMap.style.addLayer(
      FillLayer(
        id: fillLayerId3,
        slot: 'top',
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: ['==', ['get', 'risk_level'], 3],
        fillColor: Colors.blue.withValues(alpha: 0.9).toARGB32(),
      ),
    );

    await mapboxMap.style.addLayer(
      LineLayer(
        id: outlineLayerId,
        slot: 'top',
        sourceId: sourceId,
        sourceLayer: 'flooded',
        lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
        lineWidth: 1.0,
      ),
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
