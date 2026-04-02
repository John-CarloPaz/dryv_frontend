import 'package:flutter/foundation.dart';

class CrucialFacilityMapSelection {
  final double lat;
  final double lng;
  final String name;
  final String address;

  const CrucialFacilityMapSelection({
    required this.lat,
    required this.lng,
    required this.name,
    required this.address,
  });
}

class CrucialFacilitySelectionState {
  CrucialFacilitySelectionState._();

  static final ValueNotifier<CrucialFacilityMapSelection?> selected =
      ValueNotifier<CrucialFacilityMapSelection?>(null);

  static void select(CrucialFacilityMapSelection selection) {
    selected.value = selection;
  }

  static void clear() {
    selected.value = null;
  }
}
