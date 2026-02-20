import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dryvmobapp/Providers/auth_provider.dart';
import 'package:dryvmobapp/Screens/Authentication/login_page.dart';
import 'package:dryvmobapp/Widgets/bottom_navigation.dart';
import 'package:dryvmobapp/Screens/Map/map_display.dart';
import 'package:dryvmobapp/Screens/Forecast/forecast_screen.dart';
import 'package:dryvmobapp/Screens/CrucialLocations/crucial_locations_screen.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(authTokenProvider);

    return tokenAsync.when(
      loading: () {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      },
      error: (err, _) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Failed to load session.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('$err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(authTokenProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (token) {
        if (token == null || token.isEmpty) return const LoginPage();
        return const BottomNavWidget(
          pages: [MapScreen(), CrucialLocationsScreen(), ForecastScreen()],
        );
      },
    );
  }
}
