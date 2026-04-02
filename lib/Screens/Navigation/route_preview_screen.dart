import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Services/backend_routing_service.dart';
import 'package:dryvmobapp/Services/backend_route_geometry.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:dryvmobapp/Services/map_service.dart';
import 'package:dryvmobapp/Services/realtime_flood_overlay_state.dart';
import 'package:dryvmobapp/Services/route_line_overlay_service.dart';
import 'package:dryvmobapp/Services/app_activity_state.dart';
import 'package:dryvmobapp/Widgets/route_info_sheet.dart';
import 'package:dryvmobapp/Models/lat_lng.dart' as dryv;

import 'driving_screen.dart';

class RoutePreviewScreen extends StatefulWidget {
  final BackendApprovedRoute approved;
  final dryv.LatLng origin;
  final dryv.LatLng destination;
  final String originLabel;
  final String destinationLabel;
  final String vehicleType;
  final bool avoidMotorways;
  final bool avoidCommunityFloodReports;

  const RoutePreviewScreen({
    super.key,
    required this.approved,
    required this.origin,
    required this.destination,
    required this.originLabel,
    required this.destinationLabel,
    required this.vehicleType,
    required this.avoidMotorways,
    required this.avoidCommunityFloodReports,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  bool _overlayApplied = false;

  final MapService _mapService = MapService();
  bool _realtimeFloodEnabled = false;
  late final VoidCallback _realtimeFloodGlobalListener;

  PointAnnotationManager? _annotationManager;
  PointAnnotation? _destinationPin;
  Uint8List? _pinImage;

  @override
  void initState() {
    super.initState();

    // Suppress flood-nearby notifications while previewing a route.
    AppActivityState.setInRoutePreview(true);

    _realtimeFloodEnabled = RealtimeFloodOverlayState.isEnabled;
    _realtimeFloodGlobalListener = () {
      _setRealtimeFloodEnabled(
        RealtimeFloodOverlayState.isEnabled,
        updateGlobal: false,
      );
    };
    RealtimeFloodOverlayState.enabled.addListener(_realtimeFloodGlobalListener);
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraOptions(zoom: 13.5);

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: initialCamera,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) {
              // If the style is updated/reloaded, runtime layers are reset.
              // Re-apply realtime flood overlay if it's enabled.
              _mapService.reapplyRealtimeFloodLayer();
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _TopRoutePanel(
              originLabel: widget.originLabel,
              destinationLabel: widget.destinationLabel,
            ),
          ),
          if (_mapReady)
            Positioned(
              right: 14,
              bottom: 250,
              child: FloatingActionButton(
                heroTag: 'fab-flood-route-preview',
                backgroundColor: Colors.white,
                mini: true,
                elevation: 2,
                onPressed: _toggleRealtimeFlood,
                child: Icon(
                  Icons.waves,
                  color: _realtimeFloodEnabled
                      ? const Color(0xFF0B7D5A)
                      : Colors.grey,
                ),
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

    await _mapService.attachMap(mapboxMap);

    // Enable the location puck (permission is handled earlier in the flow).
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    setState(() {
      _mapReady = true;
    });

    await _applyRouteOverlayOnce();

    // Apply realtime flood overlay (if enabled globally) once the route exists.
    await _setRealtimeFloodEnabled(
      RealtimeFloodOverlayState.isEnabled,
      updateGlobal: false,
    );
  }

  Future<void> _toggleRealtimeFlood() async {
    await _setRealtimeFloodEnabled(!_realtimeFloodEnabled, updateGlobal: true);
  }

  Future<void> _setRealtimeFloodEnabled(
    bool enabled, {
    required bool updateGlobal,
  }) async {
    if (!mounted) return;

    if (_realtimeFloodEnabled != enabled) {
      setState(() => _realtimeFloodEnabled = enabled);
    }

    if (_mapService.isInitialized) {
      await _mapService.setRealtimeFloodEnabled(
        enabled,
        layerPosition: LayerPosition(
          below: RouteLineOverlayService.completedLayerId,
        ),
      );
    }

    if (updateGlobal) {
      RealtimeFloodOverlayState.setEnabled(enabled);
    }
  }

  Future<void> _applyRouteOverlayOnce() async {
    if (_overlayApplied) return;
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final extracted = BackendRouteGeometry.tryExtractLineStringCoordinates(
      widget.approved.geometryGeoJson,
      originHint: widget.origin,
      destinationHint: widget.destination,
    );

    final extractedBroken = extracted == null
        ? true
        : BackendRouteGeometry.isProbablyBroken(extracted);

    final fromSteps = extractedBroken
        ? BackendRouteGeometry.tryExtractFromStepsJson(
            widget.approved.stepsJson,
            originHint: widget.origin,
            destinationHint: widget.destination,
          )
        : null;

    List<dryv.LatLng> rawCoords;
    String using;
    if (extracted != null && !extractedBroken) {
      rawCoords = extracted;
      using = 'geometry';
    } else if (fromSteps != null && fromSteps.length >= 2) {
      rawCoords = fromSteps;
      using = 'steps';
    } else {
      rawCoords = widget.approved.waypoints;
      using = 'waypoints';
    }

    final chosenGap = rawCoords.length < 2
        ? null
        : BackendRouteGeometry.maxConsecutiveGapMeters(rawCoords);

    AppFileLogger.instance.info(
      'RoutePreview overlay: extracted=${extracted?.length ?? 0} '
      'steps=${fromSteps?.length ?? 0} '
      'waypoints=${widget.approved.waypoints.length} '
      'using=$using '
      'broken=${extractedBroken ? 'yes' : 'no'} '
      'maxGap=${chosenGap?.toStringAsFixed(1) ?? 'n/a'}m '
      'first=${rawCoords.first.lat},${rawCoords.first.lng} '
      'last=${rawCoords.last.lat},${rawCoords.last.lng}',
    );

    if (rawCoords.length < 2) return;

    final coords = BackendRouteGeometry.cleanCoordinates(
      BackendRouteGeometry.orientOriginToDestination(
        rawCoords,
        origin: widget.origin,
        destination: widget.destination,
      ),
    );

    // Use the app palette blue for better contrast on satellite.
    await RouteLineOverlayService.apply(
      mapboxMap: mapboxMap,
      coordinates: coords,
      color: const Color(0xFF2F80ED),
    );

    await _ensureDestinationPin(coords.last);

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

  Future<void> _ensureDestinationPin(dryv.LatLng dest) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    try {
      _annotationManager ??= await mapboxMap.annotations
          .createPointAnnotationManager();
    } catch (_) {
      return;
    }

    final mgr = _annotationManager;
    if (mgr == null) return;

    try {
      final existing = _destinationPin;
      if (existing != null) {
        await mgr.delete(existing);
        _destinationPin = null;
      }
    } catch (_) {}

    _pinImage ??= (await rootBundle.load(
      'lib/assets/images/pin.png',
    )).buffer.asUint8List();

    try {
      _destinationPin = await mgr.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(dest.lng, dest.lat)),
          image: _pinImage,
          iconSize: 0.34,
        ),
      );
    } catch (_) {
      // Ignore annotation failures.
    }
  }

  void _startDriving() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DrivingScreen(
          approved: widget.approved,
          origin: widget.origin,
          destination: widget.destination,
          originLabel: widget.originLabel,
          destinationLabel: widget.destinationLabel,
          vehicleType: widget.vehicleType,
          avoidMotorways: widget.avoidMotorways,
          avoidCommunityFloodReports: widget.avoidCommunityFloodReports,
        ),
      ),
    );
  }

  @override
  void dispose() {
    AppActivityState.setInRoutePreview(false);
    RealtimeFloodOverlayState.enabled.removeListener(
      _realtimeFloodGlobalListener,
    );
    _mapService.dispose();
    final mapboxMap = _mapboxMap;
    if (mapboxMap != null) {
      RouteLineOverlayService.remove(mapboxMap: mapboxMap);
    }
    try {
      _annotationManager?.deleteAll();
    } catch (_) {}
    super.dispose();
  }
}

class _TopRoutePanel extends StatelessWidget {
  final String originLabel;
  final String destinationLabel;

  const _TopRoutePanel({
    required this.originLabel,
    required this.destinationLabel,
  });

  @override
  Widget build(BuildContext context) {
    const cPrimary = Color(0xFF13005A);
    const cDarkBlue = Color(0xFF00337C);
    const cBlue = Color(0xFF1C82AD);
    const cAccent = Color(0xFF03C988);

    return SafeArea(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.my_location, size: 18, color: cPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      originLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cDarkBlue.withValues(alpha: 0.90),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.place, size: 18, color: cPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destinationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
