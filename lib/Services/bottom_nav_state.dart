import 'package:flutter/foundation.dart';

class BottomNavState {
  BottomNavState._();

  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  static void setIndex(int value) {
    if (index.value == value) return;
    index.value = value;
  }
}
