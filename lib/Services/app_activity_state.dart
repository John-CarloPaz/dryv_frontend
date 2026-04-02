import 'package:shared_preferences/shared_preferences.dart';

class AppActivityState {
  static const _kInRoutePreview = 'app_activity_in_route_preview';
  static const _kInDriving = 'app_activity_in_driving';

  static const _kLastNotifiedHadNearbyFlood =
      'flood_nearby_last_notified_had_nearby_flood';

  static const _kLastFloodNearbyNotificationAtMs =
      'flood_nearby_last_notification_at_ms';

  static Future<void> setInRoutePreview(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInRoutePreview, value);
  }

  static Future<void> setInDriving(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInDriving, value);
  }

  static Future<bool> isInRoutePreview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInRoutePreview) ?? false;
  }

  static Future<bool> isInDriving() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInDriving) ?? false;
  }

  static Future<bool> lastNotifiedHadNearbyFlood() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLastNotifiedHadNearbyFlood) ?? false;
  }

  static Future<void> setLastNotifiedHadNearbyFlood(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLastNotifiedHadNearbyFlood, value);
  }

  static Future<DateTime?> lastFloodNearbyNotificationAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastFloodNearbyNotificationAtMs);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastFloodNearbyNotificationAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastFloodNearbyNotificationAtMs,
      value.millisecondsSinceEpoch,
    );
  }
}
