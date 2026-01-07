import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GroupedButtons extends StatelessWidget {
	final MapboxMap mapboxMap;
	final bool isUserLocationEnabled;
	final VoidCallback onToggleUserLocation;

	const GroupedButtons({
		super.key,
		required this.mapboxMap,
		required this.isUserLocationEnabled,
		required this.onToggleUserLocation,
	});

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
					onPressed: onToggleUserLocation,
					child: Icon(
						isUserLocationEnabled ? Icons.my_location : Icons.location_searching,
						color: Colors.grey,
					),
				),
				const SizedBox(height: 10),
				LayerButtonWidget(
					mapboxMap: mapboxMap,
				),
			],
		);
	}
}
