import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthTokenNotifier extends Notifier<String?> {
	@override
	String? build() => null;

	void setToken(String? token) => state = token;

	void clear() => state = null;
}

// Simple in-memory auth token provider.
final authProvider = NotifierProvider<AuthTokenNotifier, String?>(
	AuthTokenNotifier.new,
);
