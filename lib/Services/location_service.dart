import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized helper for requesting location permission and reading an origin
/// coordinate for the backend.
///
/// SAFETY:
/// - Used only to determine origin sent to the backend.
/// - We do not compute or alter routes on-device.
class LocationService {
  static Future<Map<String, double>?> getLastKnownLocation() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return {'lat': last.latitude, 'lng': last.longitude};
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return {'lat': current.latitude, 'lng': current.longitude};
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLocationServicesEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
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
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return openAppSettings();
    }
  }

  static Future<bool> ensureLocationServicesEnabled(
    BuildContext context,
  ) async {
    final enabled = await isLocationServicesEnabled();
    if (enabled) return true;
    if (!context.mounted) return false;

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

    if (!context.mounted) return false;

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
