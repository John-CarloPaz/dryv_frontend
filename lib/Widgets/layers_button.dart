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
  }

  Future<void> _toggleFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    if (_isFloodLayerVisible) {
      // Remove flood layers + source
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

      setState(() => _isFloodLayerVisible = false);
      // notify parent to re-apply overlays if needed
      widget.onStyleChanged?.call();
    } else {
      try {
        // ✅ Add hosted vector tileset as source
        await mapboxMap.style.addSource(
          VectorSource(
            id: 'flood_source',
            url: 'mapbox://johncarlo123.pampanga-flood-map',
          ),
        );

        // 🗺️ Add categorized layers by `Var` property (note uppercase V)
        await mapboxMap.style.addLayer(
          FillLayer(
            id: 'flood-layer-var1',
            sourceId: 'flood_source',
            sourceLayer: 'flood', // must match Mapbox
            filter: ['==', ['get', 'Var'], 1], // property name is Var
            fillColor: Colors.yellow.withValues(alpha: .6).toARGB32(),
          ),
        );

        await mapboxMap.style.addLayer(
          FillLayer(
            id: 'flood-layer-var2',
            sourceId: 'flood_source',
            sourceLayer: 'flood',
            filter: ['==', ['get', 'Var'], 2],
            fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
          ),
        );

        await mapboxMap.style.addLayer(
          FillLayer(
            id: 'flood-layer-var3',
            sourceId: 'flood_source',
            sourceLayer: 'flood',
            filter: ['==', ['get', 'Var'], 3],
            fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
          ),
        );

        setState(() => _isFloodLayerVisible = true);
        debugPrint('✅ Flood layer loaded successfully.');
        // Let parent re-apply overlays (like realtime flood polygon) so they sit above these layers
        widget.onStyleChanged?.call();
      } catch (e, st) {
        debugPrint('❌ Failed to load flood layer: $e\n$st');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add flood layer')),
        );
      }
    }
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
