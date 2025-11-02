import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/Widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap mapboxMap;

  final defaultLng = 120.592083;
  final defaultLat = 15.158430;

  @override
  Widget build(BuildContext context) {
    final camera = CameraOptions(
      center: Point(coordinates: Position(defaultLng, defaultLat)),
      zoom: 12,
    );

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: camera,
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
            ),
          ),

          if (mapboxMapInitialized) 
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(mapboxMap: mapboxMap),
            ),
        ],
      )
    );
  }

  bool mapboxMapInitialized = false;

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

    if (result != null && mounted) {
      final lng = result['lng'];
      final lat = result['lat'];
      final name = result['name'];
      
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }
}
