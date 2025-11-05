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

  // === CATEGORIES (NOW WITH PARKING) ===
  final Map<String, List<Map<String, dynamic>>> _categories = {
    'Crucial Facilities': [
      {
        'name': 'Pampanga Provincial Capitol Evacuation Center',
        'lat': 15.024007,
        'lng': 120.68732,
        'color': Colors.redAccent,
        'icon': Icons.location_city,
      },
      {
        'name': 'Jose B. Lingad Memorial Regional Hospital',
        'lat': 15.03448,
        'lng': 120.68466,
        'color': Colors.blueAccent,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Angeles City Disaster Operations Center',
        'lat': 15.133078,
        'lng': 120.590011,
        'color': Colors.orangeAccent,
        'icon': Icons.security,
      },
      {
        'name': 'Clark Freeport Relief Distribution Point',
        'lat': 15.1850,
        'lng': 120.5410,
        'color': Colors.green,
        'icon': Icons.local_shipping,
      },
      {
        'name': 'Barangay Sindalan Flood Shelter',
        'lat': 15.0833,
        'lng': 120.6433,
        'color': Colors.purple,
        'icon': Icons.home,
      },
      {
        'name': 'San Fernando City Police Station',
        'lat': 15.0674,
        'lng': 120.6542,
        'color': Colors.blue,
        'icon': Icons.local_police,
      },
      {
        'name': 'Mabalacat City Fire Station',
        'lat': 15.2005,
        'lng': 120.5841,
        'color': Colors.red,
        'icon': Icons.local_fire_department,
      },
      {
        'name': 'Holy Angel University',
        'lat': 15.133078,
        'lng': 120.590011,
        'color': Colors.teal,
        'icon': Icons.school,
      },
      {
        'name': 'Angeles University Foundation Medical Center',
        'lat': 15.1453,
        'lng': 120.5950,
        'color': Colors.indigo,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'St. Catherine Hospital',
        'lat': 15.1304,
        'lng': 120.5762,
        'color': Colors.pinkAccent,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Systems Plus College Foundation',
        'lat': 15.1592,
        'lng': 120.5932,
        'color': Colors.deepOrange,
        'icon': Icons.school,
      },
    ],
    'Hospitals': [
      {
        'name': 'Jose B. Lingad Memorial Regional Hospital',
        'lat': 15.03448,
        'lng': 120.68466,
        'color': Colors.blueAccent,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Angeles University Foundation Medical Center',
        'lat': 15.1453,
        'lng': 120.5950,
        'color': Colors.indigo,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'St. Catherine Hospital',
        'lat': 15.1304,
        'lng': 120.5762,
        'color': Colors.pinkAccent,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Mother Teresa of Calcutta Medical Center',
        'lat': 15.0501,
        'lng': 120.6902,
        'color': Colors.cyan,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'The Medical City Clark',
        'lat': 15.1705,
        'lng': 120.5812,
        'color': Colors.deepPurple,
        'icon': Icons.local_hospital,
      },
      {
        'name': 'Rafael Lazatin Memorial Medical Center',
        'lat': 15.1333,
        'lng': 120.5890,
        'color': Colors.teal,
        'icon': Icons.local_hospital,
      },
    ],
    'Evacuation Centers': [
      {
        'name': 'Pampanga Provincial Capitol Evacuation Center',
        'lat': 15.024007,
        'lng': 120.68732,
        'color': Colors.redAccent,
        'icon': Icons.location_city,
      },
      {
        'name': 'Holy Angel University Gym',
        'lat': 15.133078,
        'lng': 120.590011,
        'color': Colors.orange,
        'icon': Icons.sports,
      },
      {
        'name': 'Sindalan Elementary School',
        'lat': 15.0833,
        'lng': 120.6433,
        'color': Colors.purple,
        'icon': Icons.school,
      },
      {
        'name': 'Clark Parade Grounds',
        'lat': 15.1850,
        'lng': 120.5410,
        'color': Colors.green,
        'icon': Icons.park,
      },
      {
        'name': 'Mabalacat City Hall Grounds',
        'lat': 15.2230,
        'lng': 120.5730,
        'color': Colors.brown,
        'icon': Icons.account_balance,
      },
    ],
    'Restaurants': [
      {
        'name': 'Everybody\'s Cafe',
        'lat': 15.0280,
        'lng': 120.6930,
        'color': Colors.orange,
        'icon': Icons.restaurant,
      },
      {
        'name': 'Apag Marangle',
        'lat': 15.0330,
        'lng': 120.6890,
        'color': Colors.deepOrange,
        'icon': Icons.restaurant,
      },
      {
        'name': 'Sushi Nori',
        'lat': 15.1400,
        'lng': 120.5950,
        'color': Colors.green,
        'icon': Icons.ramen_dining,
      },
      {
        'name': 'Binulo Restaurant',
        'lat': 15.1600,
        'lng': 120.5800,
        'color': Colors.amber,
        'icon': Icons.restaurant_menu,
      },
      {
        'name': 'Cely\'s Seafood House',
        'lat': 15.0700,
        'lng': 120.6500,
        'color': Colors.blue,
        'icon': Icons.set_meal,
      },
    ],
    'Hotels': [
      {
        'name': 'Clark Marriott Hotel',
        'lat': 15.1708,
        'lng': 120.5820,
        'color': Colors.purple[700],
        'icon': Icons.hotel,
      },
      {
        'name': 'Widuss Hotel Clark',
        'lat': 15.1720,
        'lng': 120.5830,
        'color': Colors.purple,
        'icon': Icons.hotel,
      },
      {
        'name': 'Park Inn by Radisson',
        'lat': 15.1650,
        'lng': 120.5850,
        'color': Colors.blue,
        'icon': Icons.hotel,
      },
      {
        'name': 'Savoy Hotel Clark',
        'lat': 15.1680,
        'lng': 120.5800,
        'color': Colors.cyan,
        'icon': Icons.hotel,
      },
      {
        'name': 'Quest Hotel Clark',
        'lat': 15.1620,
        'lng': 120.5870,
        'color': Colors.teal,
        'icon': Icons.hotel,
      },
    ],
    'Charging Stations': [
      {
        'name': 'SM City Clark EV Station',
        'lat': 15.1655,
        'lng': 120.5825,
        'color': Colors.green,
        'icon': Icons.electric_car,
      },
      {
        'name': 'Marquee Mall Charging',
        'lat': 15.1600,
        'lng': 120.5950,
        'color': Colors.lightGreen,
        'icon': Icons.electric_bolt,
      },
      {
        'name': 'Clark Freeport Charging Hub',
        'lat': 15.1800,
        'lng': 120.5400,
        'color': Colors.lime,
        'icon': Icons.ev_station,
      },
      {
        'name': 'Petron Gas & Charge',
        'lat': 15.0700,
        'lng': 120.6500,
        'color': Colors.greenAccent,
        'icon': Icons.electric_car,
      },
      {
        'name': 'Shell Recharge',
        'lat': 15.1300,
        'lng': 120.5900,
        'color': Colors.green[700],
        'icon': Icons.electric_bolt,
      },
    ],
    // === NEW: PARKING SPACES ===
    'Parking Spaces': [
      {
        'name': 'SM City Clark Parking',
        'lat': 15.1655,
        'lng': 120.5825,
        'color': Colors.brown[700],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Marquee Mall Parking',
        'lat': 15.1600,
        'lng': 120.5950,
        'color': Colors.brown[600],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Clark Parade Grounds Parking',
        'lat': 15.1850,
        'lng': 120.5410,
        'color': Colors.brown[800],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Robinsons Place Angeles Parking',
        'lat': 15.1400,
        'lng': 120.5950,
        'color': Colors.brown[500],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Nepo Mall Parking',
        'lat': 15.1330,
        'lng': 120.5900,
        'color': Colors.brown[400],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Jenra Mall Parking',
        'lat': 15.0280,
        'lng': 120.6930,
        'color': Colors.brown[900],
        'icon': Icons.local_parking,
      },
      {
        'name': 'Pampanga Capitol Parking',
        'lat': 15.0240,
        'lng': 120.6870,
        'color': Colors.brown[300],
        'icon': Icons.local_parking,
      },
    ],
  };

  String? _activeCategory;

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

  Future<void> _showPins(String category) async {
    if (_annotationManager == null) return;

    await _annotationManager!.deleteAll();

    final locations = _categories[category]!;
    for (final loc in locations) {
      final image = await _createPin(loc['color']);
      await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(loc['lng'], loc['lat'])),
          image: image,
          iconSize: 1.0,
          iconOffset: [0, -20],
          textField: loc['name'],
          textOffset: [0, -40],
          textColor: Colors.black.value,
          textSize: 11,
        ),
      );
    }

    setState(() => _activeCategory = category);
  }

  Future<void> _hidePins() async {
    if (_annotationManager == null) return;
    await _annotationManager!.deleteAll();
    setState(() => _activeCategory = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(onTap: _openSearchScreen),
          ),

          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(mapboxMap: mapboxMap),
            ),

          Positioned(
            top: 110,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.keys.map((category) {
                  final isActive = _activeCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        _categories[category]![0]['icon'],
                        size: 18,
                        color: isActive ? Colors.white : null,
                      ),
                      label: Text(
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : null,
                        ),
                      ),
                      backgroundColor: isActive
                          ? Colors.redAccent
                          : Colors.white,
                      elevation: isActive ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: isActive
                              ? Colors.redAccent
                              : Colors.grey[300]!,
                        ),
                      ),
                      onPressed: () {
                        if (isActive) {
                          _hidePins();
                        } else {
                          _showPins(category);
                        }
                      },
                    ),
                  );
                }).toList(),
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
