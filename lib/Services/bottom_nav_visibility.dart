import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Controls whether the bottom navigation bar should be visible.
///
/// Uses a simple reference-count so multiple overlays can hide the nav without
/// flicker.
class BottomNavVisibility {
  static final ValueNotifier<int> _hideCount = ValueNotifier<int>(0);

  static ValueListenable<int> get hideCountListenable => _hideCount;

  static bool get isVisible => _hideCount.value <= 0;

  /// Acquire a "hide" lease. Call the returned function to release it.
  static VoidCallback acquireHide() {
    _hideCount.value = _hideCount.value + 1;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _hideCount.value = math.max(0, _hideCount.value - 1);
    };
  }
}
