import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple in-memory auth token provider.
final authProvider = StateProvider<String?>((ref) => null);
