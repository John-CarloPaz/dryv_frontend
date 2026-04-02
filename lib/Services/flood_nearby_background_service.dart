import 'dart:io';
import 'dart:ui';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Services/app_activity_state.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:dryvmobapp/Services/flood_nearby_service.dart';
import 'package:dryvmobapp/Services/notification_service.dart';

class FloodNearbyBackgroundService {
  static const double _nearbyMetersThreshold = 200;
  static bool _debugScheduledOnceThisRun = false;

  // Prevent rapid duplicate notifications if BackgroundFetch triggers in bursts.
  static const Duration _minNotifyInterval = Duration(minutes: 1);

  static Future<void> start() async {
    try {
      final status = await BackgroundFetch.status;
      AppFileLogger.instance.info('BackgroundFetch status=$status');
    } catch (_) {
      // Ignore status lookup failures.
    }

    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 1,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        // Android note: minimumFetchInterval is only a hint; JobScheduler may
        // defer tasks heavily under Doze/battery restrictions. AlarmManager is
        // more eager but more battery intensive.
        forceAlarmManager: Platform.isAndroid,
        requiredNetworkType: NetworkType.ANY,
      ),
      (taskId) async {
        try {
          await _performCheck(taskId: taskId, headless: false);
        } catch (e, st) {
          AppFileLogger.instance.error(
            'Background flood check failed (taskId=$taskId)',
            err: e,
            stack: st,
          );
        } finally {
          BackgroundFetch.finish(taskId);
        }
      },
      (taskId) async {
        AppFileLogger.instance.info('BackgroundFetch timeout (taskId=$taskId)');
        BackgroundFetch.finish(taskId);
      },
    );

    await BackgroundFetch.start();

    // Debug helper: schedule a one-off task shortly after startup so you can
    // verify the pipeline (location -> /flood/nearby -> local notification).
    if (kDebugMode && !_debugScheduledOnceThisRun) {
      _debugScheduledOnceThisRun = true;
      try {
        await BackgroundFetch.scheduleTask(
          TaskConfig(
            taskId: 'flood_nearby_debug_once',
            delay: 8000,
            periodic: false,
            stopOnTerminate: false,
            enableHeadless: true,
            requiredNetworkType: NetworkType.ANY,
          ),
        );
        AppFileLogger.instance.info(
          'Scheduled debug BackgroundFetch task flood_nearby_debug_once',
        );
      } catch (e, st) {
        AppFileLogger.instance.error(
          'Failed scheduling debug BackgroundFetch task',
          err: e,
          stack: st,
        );
      }
    }
  }

  static Future<void> _performCheck({
    required String taskId,
    required bool headless,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    AppFileLogger.instance.info(
      'FloodNearbyBackgroundService check start taskId=$taskId headless=$headless',
    );

    try {
      if (!dotenv.isInitialized) {
        await dotenv.load();
      }
    } catch (_) {
      // If dotenv fails, FloodNearbyService will throw; swallow below.
    }

    // Always fetch data with the user's *current* location.
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppFileLogger.instance.info(
        'FloodNearbyBackgroundService: location permission not granted ($permission)',
      );
      return;
    }

    // On iOS, background/headless location requires Always permission.
    if (Platform.isIOS &&
        headless &&
        permission == LocationPermission.whileInUse) {
      AppFileLogger.instance.info(
        'FloodNearbyBackgroundService: iOS headless requires Always permission; skipping',
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    AppFileLogger.instance.info(
      'FloodNearbyBackgroundService: got location lat=${pos.latitude} lng=${pos.longitude}',
    );

    final resp = await FloodNearbyService().fetchNearby(
      location: LatLng(lat: pos.latitude, lng: pos.longitude),
    );

    final nearby =
        resp.floodedRoads
            .where((r) => r.metersAway <= _nearbyMetersThreshold)
            .toList()
          ..sort((a, b) {
            final riskCmp = (b.riskLevel).compareTo(a.riskLevel);
            if (riskCmp != 0) return riskCmp;
            return (a.metersAway).compareTo(b.metersAway);
          });

    final hasNearby = nearby.isNotEmpty;

    final suppressed =
        (await AppActivityState.isInRoutePreview()) ||
        (await AppActivityState.isInDriving());

    AppFileLogger.instance.info(
      'FloodNearbyBackgroundService: hasNearby=$hasNearby nearbyCount=${nearby.length} suppressed=$suppressed',
    );

    // Reset notification state when there is no longer nearby flooding.
    if (!hasNearby) {
      AppFileLogger.instance.info(
        'FloodNearbyBackgroundService: no nearby flood',
      );
      return;
    }

    // Fetch still happens even if suppressed, but notifications are disabled.
    if (suppressed) {
      AppFileLogger.instance.info(
        'FloodNearbyBackgroundService: suppressed; skipping notification',
      );
      return;
    }

    final lastAt = await AppActivityState.lastFloodNearbyNotificationAt();
    final now = DateTime.now();
    if (lastAt != null && now.difference(lastAt) < _minNotifyInterval) {
      AppFileLogger.instance.info(
        'FloodNearbyBackgroundService: notify throttled; lastAt=$lastAt',
      );
      return;
    }

    final top = nearby.first;
    final title = 'Flood nearby';
    final meters = top.metersAway.isFinite ? top.metersAway.round() : null;
    final body = meters == null
        ? '${top.roadName} has flood risk nearby.'
        : '${top.roadName} is ~${meters}m away (risk ${top.riskLevel}).';

    await NotificationService.showFloodNearby(title: title, body: body);
    await AppActivityState.setLastFloodNearbyNotificationAt(now);
    AppFileLogger.instance.info(
      'FloodNearbyBackgroundService: notification sent',
    );
  }
}

@pragma('vm:entry-point')
void floodNearbyBackgroundFetchHeadlessTask(HeadlessTask task) async {
  final taskId = task.taskId;
  final timeout = task.timeout;
  if (timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }

  try {
    await FloodNearbyBackgroundService._performCheck(
      taskId: taskId,
      headless: true,
    );
  } catch (_) {
    // Best-effort: background tasks should never crash the isolate.
  } finally {
    BackgroundFetch.finish(taskId);
  }
}
