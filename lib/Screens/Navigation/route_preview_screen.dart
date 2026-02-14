import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Services/backend_routing_service.dart';
import 'package:dryvmobapp/Services/backend_route_geometry.dart';
import 'package:dryvmobapp/Services/route_line_overlay_service.dart';
import 'package:dryvmobapp/Widgets/route_info_sheet.dart';

import 'driving_screen.dart';

class RoutePreviewScreen extends StatefulWidget {
  final BackendApprovedRoute approved;
  final String originLabel;
  final String destinationLabel;

  const RoutePreviewScreen({
    super.key,
    required this.approved,
    required this.originLabel,
    required this.destinationLabel,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  bool _overlayApplied = false;

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraOptions(zoom: 13.5);

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(cameraOptions: initialCamera, onMapCreated: _onMapCreated),
          Positioned(
            top: 44,
            left: 12,
            right: 12,
            child: _TopRoutePanel(
              originLabel: widget.originLabel,
              destinationLabel: widget.destinationLabel,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          if (!_mapReady) const Center(child: CircularProgressIndicator()),
          RouteInfoSheet(
            destinationName: widget.destinationLabel,
            distanceMeters: widget.approved.distanceMeters,
            durationSeconds: widget.approved.durationSeconds,
            maxRiskLevel: widget.approved.maxRiskLevel,
            onStartDriving: _startDriving,
            onExit: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Enable the location puck (permission is handled earlier in the flow).
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    setState(() {
      _mapReady = true;
    });

    await _applyRouteOverlayOnce();
  }

  Future<void> _applyRouteOverlayOnce() async {
    if (_overlayApplied) return;
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final coords =
        BackendRouteGeometry.tryExtractLineStringCoordinates(
          widget.approved.geometryGeoJson,
        ) ??
        widget.approved.waypoints;

    if (coords.length < 2) return;

    await RouteLineOverlayService.apply(
      mapboxMap: mapboxMap,
      coordinates: coords,
    );

    final points = coords
        .map((p) => Point(coordinates: Position(p.lng, p.lat)))
        .toList(growable: false);

    try {
      final camera = await mapboxMap.cameraForCoordinatesPadding(
        points,
        CameraOptions(),
        MbxEdgeInsets(top: 140, left: 60, bottom: 320, right: 60),
        null,
        null,
      );
      await mapboxMap.setCamera(camera);
    } catch (_) {
      // Best-effort; keep default camera.
    }

    _overlayApplied = true;
  }

  void _startDriving() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DrivingScreen(
          approved: widget.approved,
          originLabel: widget.originLabel,
          destinationLabel: widget.destinationLabel,
        ),
      ),
    );
  }

  @override
  void dispose() {
    final mapboxMap = _mapboxMap;
    if (mapboxMap != null) {
      RouteLineOverlayService.remove(mapboxMap: mapboxMap);
    }
    super.dispose();
  }
}

class _TopRoutePanel extends StatelessWidget {
  final String originLabel;
  final String destinationLabel;
  final VoidCallback onBack;

  const _TopRoutePanel({
    required this.originLabel,
    required this.destinationLabel,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      originLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      destinationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
