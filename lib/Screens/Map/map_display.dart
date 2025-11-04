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

  // === 8 EMERGENCY FACILITIES WITH ACCURATE COORDS ===
  static final List<Map<String, dynamic>> _facilities = [
    {
      'name': 'Capitol Evac',
      'fullName': 'Pampanga Provincial Capitol Evacuation Center',
      'lat': 15.024007,
      'lng': 120.68732,
      'color': Colors.redAccent,
      'icon': Icons.location_city,
    },
    {
      'name': 'JBL Hospital',
      'fullName': 'Jose B. Lingad Memorial Regional Hospital',
      'lat': 15.03448,
      'lng': 120.68466,
      'color': Colors.blueAccent,
      'icon': Icons.local_hospital,
    },
    {
      'name': 'HAU Gym',
      'fullName': 'Angeles City Disaster Operations Center',
      'lat': 15.133078,
      'lng': 120.590011,
      'color': Colors.orangeAccent,
      'icon': Icons.security,
    },
    {
      'name': 'Clark Relief',
      'fullName': 'Clark Freeport Relief Distribution Point',
      'lat': 15.1850,
      'lng': 120.5410,
      'color': Colors.green,
      'icon': Icons.local_shipping,
    },
    {
      'name': 'Sindalan Shelter',
      'fullName': 'Barangay Sindalan Flood Shelter',
      'lat': 15.0837,
      'lng': 120.6433,
      'color': Colors.purple,
      'icon': Icons.home,
    },
    {
      'name': 'SF Police',
      'fullName': 'San Fernando City Police Station',
      'lat': 15.0675,
      'lng': 120.6542,
      'color': Colors.blue,
      'icon': Icons.local_police,
    },
    {
      'name': 'Mabalacat Fire',
      'fullName': 'Mabalacat City Fire Station',
      'lat': 15.2006,
      'lng': 120.5840,
      'color': Colors.red,
      'icon': Icons.local_fire_department,
    },
    {
      'name': 'Holy Angel U',
      'fullName': 'Holy Angel University',
      'lat': 15.133078,
      'lng': 120.590011,
      'color': Colors.teal,
      'icon': Icons.school,
    },
    {
      'name': 'AUF Med Center', // Short name for chip
      'fullName':
          'Angeles University Foundation Medical Center', // Long name for SnackBar
      'lat': 15.1452,
      'lng': 120.5950,
      'color': Colors.blueAccent,
      'icon': Icons.local_hospital,
    },
    {
      'name': 'St. Catherine Hosp', // Short name for chip
      'fullName':
          'St. Catherine of Alexandria Foundation', // Long name for SnackBar
      'lat': 15.1304,
      'lng': 120.5762,
      'color': Colors.blue,
      'icon': Icons.local_hospital,
    },
    {
      'name': 'SPCF Foundation', // Short name for chip
      'fullName': 'Systems Plus College Foundation', // Long name for SnackBar
      'lat': 15.1585,
      'lng': 120.5924,
      'color': Colors.green,
      'icon': Icons.school,
    },

    // --- END NEW FACILITIES ---
  ];

  // Fly to location + show name
  Future<void> _flyTo(double lat, double lng, String name) async {
    if (!mapboxMapInitialized) return;

    await mapboxMap.flyTo(
      CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 17.0),
      MapAnimationOptions(duration: 1200),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name), duration: const Duration(seconds: 1)),
      );
    }
  }

  // Create colored pin
  Future<Uint8List> _createPinImage(Color color) async {
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

  // Add all markers
  Future<void> _addAllMarkers() async {
    if (_annotationManager == null) return;
    await _annotationManager!.deleteAll();

    for (final f in _facilities) {
      final image = await _createPinImage(f['color']);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          MapWidget(
            key: const ValueKey('mapbox'),
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
              await _addAllMarkers();
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

          // === HORIZONTAL FACILITY CHIPS (LIKE GOOGLE MAPS) ===
          Positioned(
            top: 110, // Just below search bar
            left: 16,
            right: 16,
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _facilities.length,
                itemBuilder: (context, index) {
                  final f = _facilities[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(f['icon'], size: 18, color: f['color']),
                      label: Text(
                        f['name'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      elevation: 2,
                      pressElevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onPressed: () =>
                          _flyTo(f['lat'], f['lng'], f['fullName']),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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
