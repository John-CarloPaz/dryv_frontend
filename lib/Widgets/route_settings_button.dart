import 'package:flutter/material.dart';

enum VehicleType { car, motorcycle, truck, walk }

extension VehicleTypeX on VehicleType {
  String get apiValue {
    switch (this) {
      case VehicleType.car:
        return 'car';
      case VehicleType.motorcycle:
        return 'motor';
      case VehicleType.truck:
        return 'truck';
      case VehicleType.walk:
        return 'walking';
    }
  }

  String get label {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.walk:
        return 'Walk';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.car:
        return Icons.directions_car;
      case VehicleType.motorcycle:
        return Icons.two_wheeler;
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.walk:
        return Icons.directions_walk;
    }
  }
}

class RouteSettingsButton extends StatelessWidget {
  final bool avoidMotorways;
  final ValueChanged<bool> onAvoidMotorwaysChanged;
  final VehicleType vehicleType;
  final ValueChanged<VehicleType> onVehicleTypeChanged;
  final bool avoidCommunityFloodReports;
  final ValueChanged<bool> onAvoidCommunityFloodReportsChanged;
  final String heroTag;

  const RouteSettingsButton({
    super.key,
    required this.avoidMotorways,
    required this.onAvoidMotorwaysChanged,
    required this.vehicleType,
    required this.onVehicleTypeChanged,
    required this.avoidCommunityFloodReports,
    required this.onAvoidCommunityFloodReportsChanged,
    this.heroTag = 'fab-route-settings',
  });

  void _openRouteSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        var localAvoidMotorways = avoidMotorways;
        var localVehicleType = vehicleType;
        var localAvoidCommunityFloodReports = avoidCommunityFloodReports;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avoid Motorways'),
                      value: localAvoidMotorways,
                      onChanged: (value) {
                        setSheetState(() => localAvoidMotorways = value);
                        onAvoidMotorwaysChanged(value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avoid community flood reports'),
                      value: localAvoidCommunityFloodReports,
                      onChanged: (value) {
                        setSheetState(
                          () => localAvoidCommunityFloodReports = value,
                        );
                        onAvoidCommunityFloodReportsChanged(value);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Vehicle type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: VehicleType.values
                          .map((type) {
                            final selected = type == localVehicleType;
                            return ChoiceChip(
                              selected: selected,
                              onSelected: (_) {
                                setSheetState(() => localVehicleType = type);
                                onVehicleTypeChanged(type);
                              },
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    type.icon,
                                    size: 18,
                                    color: selected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(type.label),
                                ],
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: Colors.white,
      mini: true,
      elevation: 2,
      onPressed: () => _openRouteSettingsSheet(context),
      child: const Icon(Icons.edit_road, color: Colors.grey),
    );
  }
}
