import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized helper for requesting location permission.
///
/// IMPORTANT: We do not fetch coordinates here (no geolocator). Mapbox's
/// LocationComponent + Viewport follow-puck behavior is responsible for
/// consuming device location.
class LocationService {
  static const MethodChannel _platformChannel = MethodChannel('dryv/platform');

  static Future<bool> isLocationServicesEnabled() async {
    try {
      final serviceStatus = await Permission.location.serviceStatus;
      return serviceStatus == ServiceStatus.enabled;
    } catch (_) {
      // If service status isn't available for some reason, don't block the user.
      return true;
    }
  }

  static Future<bool> hasLocationPermission() async {
    final permission = Platform.isIOS
        ? Permission.locationWhenInUse
        : Permission.location;
    final status = await permission.status;
    return status.isGranted;
  }

  static Future<bool> openSystemLocationSettings() async {
    if (Platform.isAndroid) {
      try {
        await _platformChannel.invokeMethod('openLocationSettings');
        return true;
      } catch (_) {
        // Fallback to app settings if platform channel fails.
        return openAppSettings();
      }
    }

    // iOS can't deep-link directly to the system Location Services toggle.
    // App settings is the closest safe destination.
    return openAppSettings();
  }

  static Future<bool> ensureLocationServicesEnabled(BuildContext context) async {
    // permission_handler exposes whether the platform location service (GPS) is enabled.
    // If it's off, Mapbox won't be able to produce location updates.
    final enabled = await isLocationServicesEnabled();
    if (enabled) return true;

    final openSettingsChoice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on location'),
        content: const Text(
          'Your GPS (Location Services) is turned off. Please turn it on to show your current position on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );

    if (openSettingsChoice == true) {
      await openSystemLocationSettings();
    }

    return false;
  }

  static Future<bool> ensureLocationPermission(BuildContext context) async {
    final permission = Platform.isIOS
        ? Permission.locationWhenInUse
        : Permission.location;

    var status = await permission.status;
    if (status.isGranted) return true;

    status = await permission.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location permission required'),
          content: const Text(
            'Please enable location permission in Settings to show your current position on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location permission denied.')),
    );
    return false;
  }
}
