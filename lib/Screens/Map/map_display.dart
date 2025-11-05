// lib/screens/map_display.dart
import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
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
  PointAnnotationManager? _annotationManager;

  final defaultLng = 120.592083;
  final defaultLat = 15.158430;

  // === 11 CRUCIAL FACILITIES ===
  static final List<Map<String, dynamic>> _facilities = [
    {
      'name': 'Pampanga Provincial Capitol Evacuation Center',
      'lat': 15.024007,
      'lng': 120.68732,
      'icon': Icons.location_city,
      'color': Colors.redAccent,
    },
    {
      'name': 'Jose B. Lingad Memorial Regional Hospital',
      'lat': 15.03448,
      'lng': 120.68466,
      'icon': Icons.local_hospital,
      'color': Colors.blueAccent,
    },
    {
      'name': 'Angeles City Disaster Operations Center',
      'lat': 15.133078,
      'lng': 120.590011,
      'icon': Icons.security,
      'color': Colors.orangeAccent,
    },
    {
      'name': 'Clark Freeport Relief Distribution Point',
      'lat': 15.1850,
      'lng': 120.5410,
      'icon': Icons.local_shipping,
      'color': Colors.green,
    },
    {
      'name': 'Barangay Sindalan Flood Shelter',
      'lat': 15.0833,
      'lng': 120.6433,
      'icon': Icons.home,
      'color': Colors.purple,
    },
    {
      'name': 'San Fernando City Police Station',
      'lat': 15.0674,
      'lng': 120.6542,
      'icon': Icons.local_police,
      'color': Colors.blue,
    },
    {
      'name': 'Mabalacat City Fire Station',
      'lat': 15.2005,
      'lng': 120.5841,
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
    {
      'name': 'Holy Angel University',
      'lat': 15.133078,
      'lng': 120.590011,
      'icon': Icons.school,
      'color': Colors.teal,
    },
    {
      'name': 'Angeles University Foundation Medical Center',
      'lat': 15.1453,
      'lng': 120.5950,
      'icon': Icons.local_hospital,
      'color': Colors.indigo,
    },
    {
      'name': 'St. Catherine Hospital',
      'lat': 15.1304,
      'lng': 120.5762,
      'icon': Icons.local_hospital,
      'color': Colors.pinkAccent,
    },
    {
      'name': 'Systems Plus College Foundation',
      'lat': 15.1592,
      'lng': 120.5932,
      'icon': Icons.school,
      'color': Colors.deepOrange,
    },
  ];

  bool _pinsVisible = false;

  // Create colored pin with white dot
  Future<Uint8List> _createPin(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;

    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size / 2, 0)
      ..lineTo(size * 0.7, size * 0.6)
      ..lineTo(size * 0.3, size * 0.6)
      ..close();

    canvas.drawPath(path, paint..color = color);
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

  // Toggle pins
  Future<void> _togglePins() async {
    if (_annotationManager == null) return;

    if (_pinsVisible) {
      await _annotationManager!.deleteAll();
      setState(() => _pinsVisible = false);
    } else {
      for (final f in _facilities) {
        final image = await _createPin(f['color']);
        await _annotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(f['lng'], f['lat'])),
            image: image,
            iconSize: 1.0,
            iconOffset: [0, -20],
            textField: f['name'],
            textOffset: [0, -40],
            textColor: Colors.black.value,
            textSize: 11,
          ),
        );
      }
      setState(() => _pinsVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          MapWidget(
            key: ValueKey('mapbox'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(defaultLng, defaultLat)),
              zoom: 12,
            ),
            onMapCreated: (controller) async {
              mapboxMap = controller;
              await mapboxMap.scaleBar.updateSettings(
                ScaleBarSettings(enabled: false),
              );
              _annotationManager = await mapboxMap.annotations
                  .createPointAnnotationManager();
              setState(() => mapboxMapInitialized = true);
            },
          ),

          // SEARCH BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(onTap: _openSearchScreen),
          ),

          // LAYER BUTTON
          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(mapboxMap: mapboxMap),
            ),

          // === "CRUCIAL FACILITIES" CHIP ===
          Positioned(
            top: 110,
            left: 16,
            child: ActionChip(
              avatar: Icon(
                Icons.security,
                size: 18,
                color: _pinsVisible ? Colors.white : null,
              ),
              label: Text(
                'Crucial Facilities',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _pinsVisible ? Colors.white : null,
                ),
              ),
              backgroundColor: _pinsVisible ? Colors.redAccent : Colors.white,
              elevation: _pinsVisible ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: _pinsVisible ? Colors.redAccent : Colors.grey[300]!,
                ),
              ),
              onPressed: _togglePins,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen()),
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
