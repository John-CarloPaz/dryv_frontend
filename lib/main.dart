import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dryvmobapp/Widgets/bottom_navigation.dart';
import 'package:dryvmobapp/Screens/Forecast/forecast_screen.dart';
import 'package:dryvmobapp/Screens/CrucialLocations/crucial_locations_screen.dart';

import 'package:dryvmobapp/Services/app_file_logger.dart';

// Screens
import 'package:dryvmobapp/Screens/Map/map_display.dart';
import 'package:dryvmobapp/Screens/Authentication/login_page.dart';
import 'package:dryvmobapp/Screens/Authentication/registration_page.dart';
import 'package:dryvmobapp/Screens/Authentication/forgot_password_page.dart';
import 'package:dryvmobapp/Screens/Legal/terms_and_conditions_page.dart';
import 'package:dryvmobapp/Screens/Intro/intro_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Init file logging early for on-device debugging.
  await AppFileLogger.instance.init();
  AppFileLogger.instance.info(
    'App starting. logFilePath=${AppFileLogger.instance.logFilePath ?? "(none)"}',
  );

  // Capture framework errors.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppFileLogger.instance.error(
      'FlutterError',
      err: details.exception,
      stack: details.stack,
    );
  };

  // Capture uncaught async errors.
  PlatformDispatcher.instance.onError = (error, stack) {
    AppFileLogger.instance.error('Uncaught error', err: error, stack: stack);
    return true;
  };

  final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  MapboxOptions.setAccessToken(accessToken);
  if (kDebugMode) {
    AppFileLogger.instance.info(
      'Mapbox access token configured (length=${accessToken.length}).',
    );
  }

  runApp(const ProviderScope(child: MyApp()));
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
      routes: {
        '/auth/login': (_) => const LoginPage(),
        '/auth/register': (_) => const RegistrationPage(),
        '/auth/forgot-password': (_) => const ForgotPasswordPage(),
        '/terms': (_) => const TermsAndConditionsPage(),
        '/home': (_) => const BottomNavWidget(
          pages: [MapScreen(), CrucialLocationsScreen(), ForecastScreen()],
        ),
      },
      home: const IntroGate(),
    );
  }
}
