import 'package:shared_preferences/shared_preferences.dart';

class IntroPreferences {
  const IntroPreferences._();

  static const _seenKey = 'intro_seen_v1';

  static Future<bool> getSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> setSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
