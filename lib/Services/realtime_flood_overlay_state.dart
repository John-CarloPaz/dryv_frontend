import 'package:flutter/foundation.dart';

/// Global app state for the Realtime Flood Map overlay.
///
/// This is intentionally lightweight (ValueNotifier) so multiple screens
/// (Home map, Route Preview, Driving) can stay in sync without introducing
/// heavier state management.
class RealtimeFloodOverlayState {
  RealtimeFloodOverlayState._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static bool get isEnabled => enabled.value;

  static void setEnabled(bool value) {
    if (enabled.value == value) return;
    enabled.value = value;
  }
}
