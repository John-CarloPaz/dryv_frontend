// lib/screens/map_display.dart
import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/Widgets/facilities_list.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap mapboxMap;
  bool mapboxMapInitialized = false;

  // Annotation manager (no need to track individual markers)
  PointAnnotationManager? _annotationManager;

  final defaultLng = 120.592083;
  final defaultLat = 15.158430;

  // Tap → Fly + Add Red Pin
  Future<void> _onFacilityTap(double lat, double lng, String name) async {
    if (!mapboxMapInitialized || _annotationManager == null) return;

    // 1. Fly to exact location
    await mapboxMap.flyTo(
      CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 17.0),
      MapAnimationOptions(duration: 1200),
    );

    // 2. Remove all previous markers
    await _annotationManager!.deleteAll();

    // 3. Create red pin image
    final image = await _createRedPinImage();

    // 4. Add new marker (v2.3.0+ API: add() returns void)
    await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        image: image,
        iconSize: 1.0,
        iconOffset: [0, -20],
        textField: name,
        textOffset: [0, -40],
        textColor: Colors.black.value,
        textSize: 12,
      ),
    );

    // 5. Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marker: $name'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Generate red pin as Uint8List
  Future<Uint8List> _createRedPinImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;

    final paint = Paint()..style = PaintingStyle.fill;

    // Red pin body
    final path = Path()
      ..moveTo(size / 2, 0)
      ..lineTo(size * 0.7, size * 0.6)
      ..lineTo(size * 0.3, size * 0.6)
      ..close();
    canvas.drawPath(path, paint..color = Colors.red);

    // White circle in center
    canvas.drawCircle(
      const Offset(size / 2, size * 0.6),
      8,
      paint..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), (size * 1.2).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
          MapWidget(
            key: const ValueKey('mapbox'),
            cameraOptions: camera,
            onMapCreated: _onMapCreated,
          ),

          // Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(onTap: _openSearchScreen),
          ),

          // Layer Button
          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(mapboxMap: mapboxMap),
            ),

          // Emergency Facilities List
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: FacilitiesList(
              onFacilityTap: (lat, lng, name) => _onFacilityTap(lat, lng, name),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Create annotation manager
    _annotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    setState(() => mapboxMapInitialized = true);
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
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
