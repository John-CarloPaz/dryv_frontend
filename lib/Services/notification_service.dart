import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:dryvmobapp/Services/app_file_logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String floodChannelId = 'flood_alerts';
  static const String floodChannelName = 'Flood alerts';
  static const String floodChannelDescription =
      'Notifications when flooding is detected near you.';

  static Future<void> init({bool requestPermissions = true}) async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    try {
      await _plugin.initialize(settings: initSettings);
    } catch (e, st) {
      AppFileLogger.instance.error(
        'NotificationService initialize failed',
        err: e,
        stack: st,
      );
      rethrow;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          floodChannelId,
          floodChannelName,
          description: floodChannelDescription,
          importance: Importance.high,
        ),
      );

      if (requestPermissions) {
        try {
          final granted = await android.requestNotificationsPermission();
          AppFileLogger.instance.info(
            'Android notification permission granted=$granted',
          );
        } catch (e, st) {
          AppFileLogger.instance.error(
            'Android notification permission request failed',
            err: e,
            stack: st,
          );
        }
      }
    }

    if (requestPermissions && Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  static Future<void> showFloodNearby({
    required String title,
    required String body,
  }) async {
    await init(requestPermissions: false);

    const androidDetails = AndroidNotificationDetails(
      floodChannelId,
      floodChannelName,
      channelDescription: floodChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
      );
      AppFileLogger.instance.info(
        'NotificationService: showed flood notification',
      );
    } catch (e, st) {
      AppFileLogger.instance.error(
        'NotificationService: show failed',
        err: e,
        stack: st,
      );
      rethrow;
    }
  }
}
