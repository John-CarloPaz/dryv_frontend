import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const accessToken = "pk.eyJ1Ijoiam9obmNhcmxvMTIzIiwiYSI6ImNtZzZrc2ZlYTBkeWwyam9pazVyc3JidWsifQ.Ydw0vEApWWCIPiZ0S1FiRw";
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap mapboxMap;

  @override
  Widget build(BuildContext context) {
    final camera = CameraOptions(
      center: Point(coordinates: Position(120.592083, 15.158430)),
      zoom: 12,
    );

    return Scaffold(
      body: 
      
      Stack ( children: [
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
              // Handle search bar tap
            },
          ),
        ),
      ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Disable scale bar
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }
}
