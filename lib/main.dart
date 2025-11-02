import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dryvmobapp/Widgets/bottom_navigation.dart';
import 'package:dryvmobapp/Screens/Search/search_screen.dart';


// Screens
import 'package:dryvmobapp/Screens/Map/map_display.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: Colors.grey.shade800,
        onSurfaceVariant: Colors.grey.shade500,
        surface: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.grey.shade800,
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
      ),
    ),
    home: const BottomNavWidget(
      pages: [
        MapScreen(),
        SearchScreen(),
        Placeholder(),
        Placeholder(),
      ],
    ),
  );
  }
}
