import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LayerButtonWidget extends StatefulWidget {
  final MapboxMap mapboxMap;
  const LayerButtonWidget({super.key, required this.mapboxMap});

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
  }

  Future<void> _toggleFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    if (_isFloodLayerVisible) {
      await mapboxMap.style.styleLayerExists('flood-layer').then((exists) async {
        if (exists) {
          await mapboxMap.style.removeStyleLayer('flood-layer');
        }
      });
      _isFloodLayerVisible = false;
    } else {
      await mapboxMap.style.addSource(
        GeoJsonSource(
          id: 'flood-source',
          data: 'https://example.com/floodmap.geojson', // Replace with real GeoJSON URL
        ),
      );

      await mapboxMap.style.addLayer(
        FillLayer(
          id: 'flood-layer',
          sourceId: 'flood-source',
          fillColor: Colors.blue.withValues(alpha: 0.4).toARGB32(),
        ),
      );
      _isFloodLayerVisible = true;
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
