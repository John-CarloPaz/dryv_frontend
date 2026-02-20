import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAuthTokenKey = 'auth_token';

class AuthTokenController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAuthTokenKey);
  }

  Future<void> setToken(String token) async {
    state = AsyncData(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthTokenKey, token);
  }

  Future<void> clear() async {
    state = const AsyncData(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthTokenKey);
  }
}

final authTokenProvider = AsyncNotifierProvider<AuthTokenController, String?>(
  AuthTokenController.new,
);
