import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple in-memory auth token provider. This uses a StateProvider so it
// doesn't rely on StateNotifier types which may vary between Riverpod versions.
final authProvider = StateProvider<String?>((ref) => null);
