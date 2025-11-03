// lib/screens/map_display.dart
import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/Widgets/facilities_list.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap mapboxMap;
  bool mapboxMapInitialized = false;

  final defaultLng = 120.592083;
  final defaultLat = 15.158430;

  get f => null;

  // ← NEW: Handle tap from facilities list
  void _onFacilityTap(double lat, double lng) {
    if (!mapboxMapInitialized) return;

    mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)), // ← lng first, then lat
        zoom: 17.0, // Closer zoom for precision
      ),
      MapAnimationOptions(duration: 1200),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Flying to ${f['name'] ?? 'facility'}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = CameraOptions(
      center: Point(coordinates: Position(defaultLng, defaultLat)),
      zoom: 12,
    );

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(cameraOptions: camera, onMapCreated: _onMapCreated),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(onTap: () => _openSearchScreen()),
          ),

          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(mapboxMap: mapboxMap),
            ),

          // ← PASS CALLBACK HERE
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: FacilitiesList(onFacilityTap: _onFacilityTap),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    setState(() => mapboxMapInitialized = true);
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );

    if (result != null && mounted && mapboxMapInitialized) {
      final lng = result['lng'] as double;
      final lat = result['lat'] as double;

      await mapboxMap.flyTo(
        CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 14),
        MapAnimationOptions(duration: 1000),
      );
    }
  }
}
