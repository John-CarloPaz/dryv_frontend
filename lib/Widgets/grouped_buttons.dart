import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/flood_legend_dialog.dart';
import 'package:dryvmobapp/Widgets/route_settings_button.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

export 'route_settings_button.dart' show VehicleType, VehicleTypeX;

class GroupedButtons extends StatefulWidget {
  final MapboxMap mapboxMap;
  final bool isUserLocationEnabled;
  final VoidCallback onToggleUserLocation;

  final bool avoidMotorways;
  final ValueChanged<bool> onAvoidMotorwaysChanged;
  final VehicleType vehicleType;
  final ValueChanged<VehicleType> onVehicleTypeChanged;

  const GroupedButtons({
    super.key,
    required this.mapboxMap,
    required this.isUserLocationEnabled,
    required this.onToggleUserLocation,
    required this.avoidMotorways,
    required this.onAvoidMotorwaysChanged,
    required this.vehicleType,
    required this.onVehicleTypeChanged,
  });

  @override
  State<GroupedButtons> createState() => _GroupedButtonsState();
}

class _GroupedButtonsState extends State<GroupedButtons> {
  FloodOverlayVisibility _overlayVisibility = const FloodOverlayVisibility(
    floodMap: false,
    realtimeFlood: false,
  );

  void _showFloodLegend() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (dialogContext) {
        final mode = _overlayVisibility.floodMap
            ? FloodLegendMode.floodMap
            : FloodLegendMode.realtimeFlood;
        return FloodLegendDialog(
          mode: mode,
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'fab-location',
          backgroundColor: Colors.white,
          mini: true,
          elevation: 2,
          onPressed: widget.onToggleUserLocation,
          child: Icon(
            widget.isUserLocationEnabled
                ? Icons.my_location
                : Icons.location_searching,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        LayerButtonWidget(
          mapboxMap: widget.mapboxMap,
          onFloodOverlayVisibilityChanged: (visibility) {
            if (!mounted) return;
            setState(() => _overlayVisibility = visibility);
          },
        ),
        const SizedBox(height: 10),
        RouteSettingsButton(
          avoidMotorways: widget.avoidMotorways,
          onAvoidMotorwaysChanged: widget.onAvoidMotorwaysChanged,
          vehicleType: widget.vehicleType,
          onVehicleTypeChanged: widget.onVehicleTypeChanged,
        ),
        if (_overlayVisibility.any) ...[
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab-flood-legend',
            backgroundColor: Colors.white,
            mini: true,
            elevation: 2,
            onPressed: _showFloodLegend,
            child: const Icon(Icons.info_outline, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}
