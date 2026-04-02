import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:dryvmobapp/Services/backend_routing_service.dart';
import 'package:dryvmobapp/Services/backend_route_geometry.dart';
import 'package:dryvmobapp/Services/flood_community_report_service.dart';
import 'package:dryvmobapp/Services/map_service.dart';
import 'package:dryvmobapp/Services/realtime_flood_overlay_state.dart';
import 'package:dryvmobapp/Services/route_line_overlay_service.dart';
import 'package:dryvmobapp/Services/app_activity_state.dart';
import 'package:dryvmobapp/Widgets/safest_route_loading.dart';

class BackendRouteStep {
  final String instruction;
  final String? maneuverType;
  final String? modifier;
  final LatLng? maneuverLatLng;
  final double? stepDistanceMeters;
  final double? bearingAfter;
  final String? roadName;
  final LatLng? maneuverLocation;

  const BackendRouteStep({
    required this.instruction,
    required this.maneuverType,
    required this.modifier,
    required this.maneuverLatLng,
    required this.stepDistanceMeters,
    required this.bearingAfter,
    required this.roadName,
    required this.maneuverLocation,
  });

  factory BackendRouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'];
    Map<String, dynamic>? maneuverMap;
    if (maneuver is Map) maneuverMap = Map<String, dynamic>.from(maneuver);

    LatLng? maneuverLatLng;
    final loc = maneuverMap?['location'];
    if (loc is List && loc.length >= 2) {
      final lng = loc[0];
      final lat = loc[1];
      if (lat is num && lng is num) {
        maneuverLatLng = LatLng(lat: lat.toDouble(), lng: lng.toDouble());
      }
    }

    final instruction = (maneuverMap?['instruction'] is String)
        ? (maneuverMap!['instruction'] as String)
        : (json['instruction'] is String)
        ? (json['instruction'] as String)
        : '';

    final stepDistance = json['distance'];
    final bearingAfter = maneuverMap?['bearing_after'];

    return BackendRouteStep(
      instruction: instruction.trim().isEmpty ? 'Continue' : instruction.trim(),
      maneuverType: maneuverMap?['type'] is String
          ? maneuverMap!['type'] as String
          : null,
      modifier: maneuverMap?['modifier'] is String
          ? maneuverMap!['modifier'] as String
          : null,
      maneuverLatLng: maneuverLatLng,
      stepDistanceMeters: stepDistance is num ? stepDistance.toDouble() : null,
      bearingAfter: bearingAfter is num ? bearingAfter.toDouble() : null,
      roadName: json['name'] is String ? (json['name'] as String) : null,
      maneuverLocation: maneuverLatLng,
    );
  }
}

class _RouteProjection {
  final int segmentIndex;
  final double t;
  final double distanceToRouteMeters;
  final double alongMeters;
  final LatLng? projectedPoint;

  const _RouteProjection({
    required this.segmentIndex,
    required this.t,
    required this.distanceToRouteMeters,
    required this.alongMeters,
    required this.projectedPoint,
  });
}

class DrivingScreen extends StatefulWidget {
  final BackendApprovedRoute approved;
  final LatLng origin;
  final LatLng destination;
  final String originLabel;
  final String destinationLabel;
  final String vehicleType;
  final bool avoidMotorways;
  final bool avoidCommunityFloodReports;

  const DrivingScreen({
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
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  ViewportState? _viewport;

  PointAnnotationManager? _annotationManager;
  final List<PointAnnotation> _routePins = [];
  Uint8List? _pinImage;
  Uint8List? _originPuckLikeImage;

  StreamSubscription<geo.Position>? _positionSub;
  LatLng? _lastGps;
  DateTime? _lastOverlayUpdateAt;
  int _lastNearestRouteIndex = 0;

  // Route metric cache / projection state.
  List<double> _routeCumMeters = const [];
  double? _currentAlongMeters;
  double? _currentDistanceToRouteMeters;
  int _lastProgressSegmentIndex = 0;
  double? _lastProgressAlongMeters;

  List<LatLng> _fullRouteCoords = const [];

  // Route progress line: keep both completed + remaining.

  List<BackendRouteStep> _steps = const [];
  List<int?> _stepRouteIndices = const [];
  List<double?> _stepAlongMeters = const [];
  int _stepIndex = 0;
  double? _distanceToManeuverMeters;
  double? _distanceToDestinationMeters;
  DateTime? _lastAdvanceAt;
  double _metersSinceAdvance = 0.0;
  bool _tbtAvailable = false;

  double? _speedKph;

  DateTime? _lastCameraAdjustAt;
  bool _turnEmphasis = false;
  bool _northUp = false;

  bool _rerouteInFlight = false;

  final MapService _mapService = MapService();
  bool _realtimeFloodEnabled = false;

  late final VoidCallback _realtimeFloodGlobalListener;

  final FloodCommunityReportService _communityReportService =
      FloodCommunityReportService();

  // Thresholds (tuneable)
  static const double _arrivalRadiusMeters = 32.0;
  static const double _advanceCooldownMeters = 15.0;
  static const Duration _advanceCooldownTime = Duration(seconds: 4);
  static const double _offRouteThresholdMeters = 60.0;
  static const double _onRouteForAdvanceMeters = 35.0;
  static const double _passedManeuverBufferMeters = 6.0;
  static const int _progressIndexDelta = 2;
  static const double _progressAlongDeltaMeters = 8.0;
  static const Duration _overlayMinInterval = Duration(milliseconds: 250);
  static const double _turnEmphasisStartMeters = 80.0;
  static const double _turnEmphasisEndMeters = 110.0;
  static const Duration _cameraMinInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    // Suppress flood-nearby notifications while actively driving.
    AppActivityState.setInDriving(true);
    // Start in follow-puck mode once the map is created.
    _viewport = _buildFollowViewport(zoom: 15.0, pitch: 0.0);

    final rawSteps = widget.approved.stepsJson;
    if (rawSteps != null && rawSteps.isNotEmpty) {
      final parsed = <BackendRouteStep>[];
      for (final s in rawSteps) {
        try {
          parsed.add(BackendRouteStep.fromJson(s));
        } catch (_) {
          // Skip malformed step.
        }
      }
      _steps = parsed;
      _tbtAvailable = parsed.isNotEmpty;
    }

    _startLocationStream();

    _realtimeFloodEnabled = RealtimeFloodOverlayState.isEnabled;
    _realtimeFloodGlobalListener = () {
      _setRealtimeFloodEnabled(
        RealtimeFloodOverlayState.isEnabled,
        updateGlobal: false,
      );
    };
    RealtimeFloodOverlayState.enabled.addListener(_realtimeFloodGlobalListener);
    AppFileLogger.instance.info(
      'DrivingScreen initialized with steps: ${_steps.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraOptions(zoom: 14.0);

    final hasSteps = _tbtAvailable && _stepIndex < _steps.length;
    final currentStep = hasSteps ? _steps[_stepIndex] : null;

    final instruction = hasSteps
        ? currentStep!.instruction
        : 'Follow the route.';

    final nextStep = (_tbtAvailable && (_stepIndex + 1) < _steps.length)
        ? _steps[_stepIndex + 1]
        : null;

    final secondary = hasSteps
        ? _formatInDistance(_distanceToManeuverMeters) +
              _formatRoadSuffix(currentStep!.roadName)
        : 'Remaining: ${_formatDistance(_distanceToDestinationMeters)}';

    final screenH = MediaQuery.of(context).size.height;
    final speedometerBottom = math.max(18.0, (screenH * 0.17) + 18.0);

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: initialCamera,
            viewport: _viewport,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) {
              // If the style is updated/reloaded, runtime layers are reset.
              // Re-apply realtime flood overlay if it's enabled.
              _mapService.reapplyRealtimeFloodLayer();
            },
          ),
          // Top instruction banner (Google Maps-like)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: SafeArea(
              child: _InstructionBanner(
                instruction: instruction,
                secondary: secondary,
                nextInstruction: nextStep?.instruction,
                modifier: currentStep?.modifier,
              ),
            ),
          ),

          // Right-side grouped buttons (aligned stack)
          if (_mapReady && _mapboxMap != null)
            Positioned(
              right: 14,
              bottom: speedometerBottom + 12,
              child: _RightButtonGroup(
                isNorthUp: _northUp,
                onToggleNorthUp: _toggleNorthUp,
                isFloodEnabled: _realtimeFloodEnabled,
                onToggleFlood: _toggleRealtimeFlood,
                onCommunityReport: _openCommunityReportSheet,
                rerouteInFlight: _rerouteInFlight,
                onReroute: _reroute,
              ),
            ),

          // Speedometer (bottom-left)
          Positioned(
            left: 14,
            bottom: speedometerBottom,
            child: SafeArea(
              top: false,
              child: _SpeedometerChip(speedKph: _speedKph),
            ),
          ),

          // Draggable driving details sheet
          Positioned.fill(
            child: _DrivingDetailsSheet(
              minSize: 0.17,
              initialSize: 0.17,
              maxSize: 0.42,
              remainingDistanceMeters: _distanceToDestinationMeters,
              onEnd: () => Navigator.of(context).pop(),
            ),
          ),

          if (!_mapReady) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Hide the built-in compass so it doesn't sit at the top-right.
    try {
      await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    } catch (_) {
      // Some styles/platforms may not expose compass settings; ignore.
    }

    await _mapService.attachMap(mapboxMap);

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

    List<LatLng> rawCoords;
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
      'Driving overlay: extracted=${extracted?.length ?? 0} '
      'steps=${fromSteps?.length ?? 0} '
      'waypoints=${widget.approved.waypoints.length} '
      'using=$using '
      'broken=${extractedBroken ? 'yes' : 'no'} '
      'maxGap=${chosenGap?.toStringAsFixed(1) ?? 'n/a'}m '
      'first=${rawCoords.first.lat},${rawCoords.first.lng} '
      'last=${rawCoords.last.lat},${rawCoords.last.lng}',
    );

    _fullRouteCoords = BackendRouteGeometry.cleanCoordinates(
      BackendRouteGeometry.orientOriginToDestination(
        rawCoords,
        origin: widget.origin,
        destination: widget.destination,
      ),
    );

    // Cache cumulative distances along the route for along-route progress + step advancement.
    _routeCumMeters = _buildCumulativeMeters(_fullRouteCoords);

    // Ensure the UI has a non-null remaining distance as soon as the route is ready.
    // This prevents the bottom sheet from showing "—" when GPS updates haven't
    // arrived yet (or the user hasn't moved).
    if (_fullRouteCoords.isNotEmpty) {
      final total = _routeCumMeters.isNotEmpty ? _routeCumMeters.last : null;
      final lastGps = _lastGps;

      if (lastGps != null && _fullRouteCoords.length >= 2 && total != null) {
        final proj = _projectPointToRoute(
          point: lastGps,
          startSegmentIndex: 0,
          endSegmentIndex: math.max(0, _fullRouteCoords.length - 2),
        );
        if (proj != null) {
          final remaining = total - proj.alongMeters;
          _distanceToDestinationMeters = remaining.isFinite
              ? math.max(0.0, remaining)
              : _distanceToDestinationMeters;
        } else {
          _distanceToDestinationMeters = _haversineMeters(
            lastGps,
            _fullRouteCoords.last,
          );
        }
      } else if (total != null) {
        _distanceToDestinationMeters ??= total;
      }
    }

    // Precompute route index + along-meters for each step maneuver.
    if (_steps.isNotEmpty) {
      final indices = <int?>[];
      final alongs = <double?>[];
      for (final s in _steps) {
        final m = s.maneuverLocation;
        if (m == null || _fullRouteCoords.length < 2) {
          indices.add(null);
          alongs.add(null);
          continue;
        }
        final proj = _projectPointToRoute(
          point: m,
          startSegmentIndex: 0,
          endSegmentIndex: math.max(0, _fullRouteCoords.length - 2),
        );
        indices.add(proj?.segmentIndex);
        alongs.add(proj?.alongMeters);
      }
      _stepRouteIndices = indices;
      _stepAlongMeters = alongs;
    }

    await RouteLineOverlayService.applyWithProgress(
      mapboxMap: mapboxMap,
      completedCoordinates: const <LatLng>[],
      remainingCoordinates: _fullRouteCoords,
    );

    // Apply realtime flood overlay (if enabled globally) once the route exists.
    await _setRealtimeFloodEnabled(
      RealtimeFloodOverlayState.isEnabled,
      updateGlobal: false,
    );

    // Enable puck AFTER the route line so it reliably renders above it.
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        // Rotate puck by course to match driving expectation.
        puckBearingEnabled: true,
        puckBearing: PuckBearing.COURSE,
        // Use an arrow-like 2D puck.
        locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
      ),
    );

    // Create annotation manager AFTER the route so pins render above the line.
    _annotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    await _ensureRoutePins();

    setState(() {
      _mapReady = true;
    });
  }

  @override
  void dispose() {
    AppActivityState.setInDriving(false);
    _positionSub?.cancel();
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

  void _startLocationStream() {
    try {
      _positionSub?.cancel();
      _positionSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {
      // Best-effort; the map can still be used.
    }
  }

  Future<void> _reroute() async {
    if (_rerouteInFlight) return;

    setState(() => _rerouteInFlight = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1) Determine origin = current location (best effort).
      LatLng? origin = _lastGps;
      if (origin == null) {
        try {
          final p = await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 8),
            ),
          );
          origin = LatLng(lat: p.latitude, lng: p.longitude);
        } catch (_) {
          // Fall back below.
        }
      }

      final originFixed = origin ?? widget.origin;

      // 2) Build backend endpoint from env; fail fast if not configured.
      final baseUrl = dotenv.env['API_BASE_URL'];
      final fallbackEndpoint = (baseUrl == null || baseUrl.trim().isEmpty)
          ? null
          : (() {
              final normalized = baseUrl.replaceAll(RegExp(r"/+$"), "");
              return normalized.endsWith('/api')
                  ? '$normalized/route/safe'
                  : '$normalized/api/route/safe';
            })();

      final endpoint =
          (dotenv.env['DRYV_SAFEST_ROUTE_URL']?.trim().isNotEmpty == true)
          ? dotenv.env['DRYV_SAFEST_ROUTE_URL']
          : fallbackEndpoint;

      if (endpoint == null || endpoint.trim().isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Backend route URL not configured. Set API_BASE_URL or DRYV_SAFEST_ROUTE_URL in .env',
            ),
          ),
        );
        return;
      }

      // 3) Show full-screen loading UI while waiting for backend response.
      if (!mounted) return;
      navigator.push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          pageBuilder: (_, __, ___) => const SafestRouteLoadingOverlay(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );

      // Ensure the overlay is on the stack before we start, so a `pop()` closes it.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final service = BackendRoutingService(
        safestRouteEndpoint: Uri.parse(endpoint),
      );

      late final BackendApprovedRoute approved;
      try {
        approved = await service.fetchSafestRoute(
          origin: originFixed,
          destination: widget.destination,
          vehicleType: widget.vehicleType,
          avoidMotorways: widget.avoidMotorways,
          toggleCommunityReport: widget.avoidCommunityFloodReports,
        );
      } on BackendRoutingException catch (e) {
        AppFileLogger.instance.warn(
          'Re-route backend exception: ${e.code} ${e.message}',
        );
        if (!mounted) return;
        navigator.pop();
        final msg = e.message.trim();
        final normalized = msg.toLowerCase();
        final isNoSafeRoute =
            e.code == 'NO_SAFE_ROUTE' ||
            normalized.contains('no safe path') ||
            normalized.contains('no safe route') ||
            normalized.contains('no found safe');

        if (isNoSafeRoute) {
          final displayMessage = msg
              .replaceAll(
                RegExp(
                  r'\bBackend returned HTTP\s+\d+\s*:\s*',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              final theme = Theme.of(dialogContext);
              final cs = theme.colorScheme;
              return AlertDialog(
                icon: Icon(Icons.route_outlined, color: cs.primary),
                title: Text(
                  'No safe path found',
                  style: theme.textTheme.titleLarge,
                ),
                content: Text(
                  displayMessage.isEmpty
                      ? 'No safe path found.'
                      : displayMessage,
                  style: theme.textTheme.bodyMedium,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        } else {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      } catch (e) {
        AppFileLogger.instance.error('Re-route unexpected error', err: e);
        if (!mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to re-route: $e')),
        );
        return;
      }

      if (!mounted) return;
      navigator.pop();

      // 4) Restart driving immediately (no preview).
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => DrivingScreen(
            approved: approved,
            origin: originFixed,
            destination: widget.destination,
            originLabel: 'Your location',
            destinationLabel: widget.destinationLabel,
            vehicleType: widget.vehicleType,
            avoidMotorways: widget.avoidMotorways,
            avoidCommunityFloodReports: widget.avoidCommunityFloodReports,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _rerouteInFlight = false);
      }
    }
  }

  void _onPosition(geo.Position p) {
    final current = LatLng(lat: p.latitude, lng: p.longitude);
    final prev = _lastGps;
    _lastGps = current;

    if (p.speed.isFinite) {
      // Geolocator speed is meters/second.
      final kph = p.speed * 3.6;
      _speedKph = kph < 0 ? 0 : kph;
    }

    if (prev != null) {
      _metersSinceAdvance += _haversineMeters(prev, current);
    }

    // Project current location onto the route polyline (segment projection)
    final proj = (_fullRouteCoords.length >= 2)
        ? _projectPointToRoute(
            point: current,
            startSegmentIndex: math.max(0, _lastNearestRouteIndex - 25),
            endSegmentIndex: math.min(
              _fullRouteCoords.length - 2,
              _lastNearestRouteIndex + 160,
            ),
          )
        : null;

    if (proj != null) {
      _lastNearestRouteIndex = proj.segmentIndex;
      _currentAlongMeters = proj.alongMeters;
      _currentDistanceToRouteMeters = proj.distanceToRouteMeters;

      // Remaining distance to destination along the route.
      final total = _routeCumMeters.isNotEmpty ? _routeCumMeters.last : null;
      if (total != null) {
        final remaining = total - proj.alongMeters;
        _distanceToDestinationMeters = remaining.isFinite
            ? math.max(0.0, remaining)
            : _distanceToDestinationMeters;
      }
    } else {
      _currentAlongMeters = null;
      _currentDistanceToRouteMeters = null;

      // Fallback destination distance.
      if (_fullRouteCoords.isNotEmpty) {
        _distanceToDestinationMeters = _haversineMeters(
          current,
          _fullRouteCoords.last,
        );
      }
    }

    // TBT state update
    if (_tbtAvailable && _stepIndex < _steps.length) {
      final step = _steps[_stepIndex];
      final m = step.maneuverLatLng;
      if (m != null) {
        // Prefer along-route distance to the maneuver (more reliable at intersections).
        final currentAlong = _currentAlongMeters;
        final stepAlong = (_stepAlongMeters.length > _stepIndex)
            ? _stepAlongMeters[_stepIndex]
            : null;
        if (currentAlong != null && stepAlong != null) {
          _distanceToManeuverMeters = math.max(0.0, stepAlong - currentAlong);
        } else {
          _distanceToManeuverMeters = _haversineMeters(current, m);
        }

        final now = DateTime.now();
        final lastAdvanceAt = _lastAdvanceAt;
        final advanceCooldownOk =
            lastAdvanceAt == null ||
            now.difference(lastAdvanceAt) >= _advanceCooldownTime;

        final closeEnough = _distanceToManeuverMeters! <= _arrivalRadiusMeters;
        final movedEnough = _metersSinceAdvance >= _advanceCooldownMeters;

        // Passed-maneuver detection: on-route + currentAlong beyond stepAlong.
        final onRoute =
            (_currentDistanceToRouteMeters ?? double.infinity) <=
            _onRouteForAdvanceMeters;
        final passedByAlong =
            onRoute &&
            currentAlong != null &&
            stepAlong != null &&
            currentAlong >= (stepAlong - _passedManeuverBufferMeters);

        // Fallback passed-by-index (legacy) when along-distance isn't available.
        final maneuverRouteIdx = (_stepRouteIndices.length > _stepIndex)
            ? _stepRouteIndices[_stepIndex]
            : null;
        final passedByIndex =
            maneuverRouteIdx != null &&
            _lastNearestRouteIndex >= math.max(0, maneuverRouteIdx - 1);

        if ((closeEnough || passedByAlong || passedByIndex) &&
            advanceCooldownOk &&
            movedEnough) {
          _stepIndex = math.min(_stepIndex + 1, _steps.length);
          _lastAdvanceAt = now;
          _metersSinceAdvance = 0.0;
          // Recompute distance-to-maneuver for new step on next tick.
          _distanceToManeuverMeters = null;
        }

        _maybeAdjustCamera(_distanceToManeuverMeters);
      }
    } else {
      _distanceToManeuverMeters = null;
      _maybeAdjustCamera(null);
    }

    _maybeTrimRouteLine(current);

    if (mounted) setState(() {});
  }

  void _maybeAdjustCamera(double? distanceToManeuverMeters) {
    final now = DateTime.now();
    final last = _lastCameraAdjustAt;
    if (last != null && now.difference(last) < _cameraMinInterval) return;

    final wantEmphasis =
        distanceToManeuverMeters != null &&
        distanceToManeuverMeters <= _turnEmphasisStartMeters;

    final wantNormal =
        distanceToManeuverMeters == null ||
        distanceToManeuverMeters >= _turnEmphasisEndMeters;

    if (wantEmphasis && !_turnEmphasis) {
      _turnEmphasis = true;
      _lastCameraAdjustAt = now;
      setState(() {
        _viewport = _buildFollowViewport(zoom: 16.5, pitch: 35.0);
      });
    } else if (wantNormal && _turnEmphasis) {
      _turnEmphasis = false;
      _lastCameraAdjustAt = now;
      setState(() {
        _viewport = _buildFollowViewport(zoom: 15.0, pitch: 0.0);
      });
    }
  }

  void _maybeTrimRouteLine(LatLng currentGps) {
    final mapboxMap = _mapboxMap;
    if (!_mapReady || mapboxMap == null) return;
    if (_fullRouteCoords.length < 2) return;

    final now = DateTime.now();
    final lastAt = _lastOverlayUpdateAt;
    if (lastAt != null && now.difference(lastAt) < _overlayMinInterval) return;

    final proj = _projectPointToRoute(
      point: currentGps,
      startSegmentIndex: math.max(0, _lastNearestRouteIndex - 25),
      endSegmentIndex: math.min(
        _fullRouteCoords.length - 2,
        _lastNearestRouteIndex + 160,
      ),
    );
    if (proj == null) return;
    if (proj.distanceToRouteMeters > _offRouteThresholdMeters) return;

    final segIdx = proj.segmentIndex;
    if (segIdx >= _fullRouteCoords.length - 2) return;

    final lastSeg = _lastProgressSegmentIndex;
    final lastAlong = _lastProgressAlongMeters;

    final forwardDelta = segIdx - lastSeg;
    final alongDelta = (lastAlong == null)
        ? double.infinity
        : (proj.alongMeters - lastAlong);

    // Update on every GPS tick *when* we have meaningful progress.
    final shouldUpdate =
        forwardDelta >= _progressIndexDelta ||
        (forwardDelta >= 0 && alongDelta >= _progressAlongDeltaMeters);
    if (!shouldUpdate) return;

    _lastProgressSegmentIndex = segIdx;
    _lastProgressAlongMeters = proj.alongMeters;
    _lastOverlayUpdateAt = now;

    // Build progress polylines with a split at the projected point.
    final projectedPoint = proj.projectedPoint;

    final completed = <LatLng>[];
    completed.addAll(_fullRouteCoords.take(segIdx + 1));
    if (projectedPoint != null) completed.add(projectedPoint);

    final remaining = <LatLng>[];
    if (projectedPoint != null) remaining.add(projectedPoint);
    remaining.addAll(_fullRouteCoords.skip(segIdx + 1));

    if (remaining.length < 2) return;

    RouteLineOverlayService.updateProgress(
      mapboxMap: mapboxMap,
      completedCoordinates: completed,
      remainingCoordinates: remaining,
    );
  }

  List<double> _buildCumulativeMeters(List<LatLng> coords) {
    if (coords.length < 2) return const <double>[];
    final out = List<double>.filled(coords.length, 0.0);
    double running = 0.0;
    for (int i = 1; i < coords.length; i++) {
      running += _haversineMeters(coords[i - 1], coords[i]);
      out[i] = running;
    }
    return out;
  }

  _RouteProjection? _projectPointToRoute({
    required LatLng point,
    required int startSegmentIndex,
    required int endSegmentIndex,
  }) {
    final coords = _fullRouteCoords;
    if (coords.length < 2) return null;
    if (_routeCumMeters.length != coords.length) return null;

    final start = math.max(0, math.min(startSegmentIndex, coords.length - 2));
    final end = math.max(start, math.min(endSegmentIndex, coords.length - 2));

    final refLatRad = _degToRad(point.lat);
    const earthRadiusMeters = 6371000.0;

    double bestDist2 = double.infinity;
    int bestSeg = start;
    double bestT = 0.0;
    LatLng? bestProj;
    double bestAlong = 0.0;

    // Convert point once.
    final px = _degToRad(point.lng) * math.cos(refLatRad) * earthRadiusMeters;
    final py = _degToRad(point.lat) * earthRadiusMeters;

    for (int i = start; i <= end; i++) {
      final a = coords[i];
      final b = coords[i + 1];

      final ax = _degToRad(a.lng) * math.cos(refLatRad) * earthRadiusMeters;
      final ay = _degToRad(a.lat) * earthRadiusMeters;
      final bx = _degToRad(b.lng) * math.cos(refLatRad) * earthRadiusMeters;
      final by = _degToRad(b.lat) * earthRadiusMeters;

      final abx = bx - ax;
      final aby = by - ay;
      final apx = px - ax;
      final apy = py - ay;

      final abLen2 = (abx * abx) + (aby * aby);
      if (abLen2 <= 0.000001) continue;

      var t = (apx * abx + apy * aby) / abLen2;
      if (t < 0.0) t = 0.0;
      if (t > 1.0) t = 1.0;

      final projx = ax + (t * abx);
      final projy = ay + (t * aby);
      final dx = px - projx;
      final dy = py - projy;
      final dist2 = (dx * dx) + (dy * dy);

      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        bestSeg = i;
        bestT = t;
        bestProj = LatLng(
          lat: a.lat + (t * (b.lat - a.lat)),
          lng: a.lng + (t * (b.lng - a.lng)),
        );

        final segLen = _routeCumMeters[i + 1] - _routeCumMeters[i];
        bestAlong = _routeCumMeters[i] + (t * segLen);
      }
    }

    if (!bestDist2.isFinite) return null;

    return _RouteProjection(
      segmentIndex: bestSeg,
      t: bestT,
      distanceToRouteMeters: math.sqrt(bestDist2),
      alongMeters: bestAlong,
      projectedPoint: bestProj,
    );
  }

  FollowPuckViewportState _buildFollowViewport({
    required double zoom,
    required double pitch,
  }) {
    return FollowPuckViewportState(
      zoom: zoom,
      pitch: pitch,
      bearing: _northUp
          ? const FollowPuckViewportStateBearingConstant(0.0)
          : const FollowPuckViewportStateBearingCourse(),
    );
  }

  void _toggleNorthUp() {
    setState(() {
      _northUp = !_northUp;
      // Keep current emphasis values.
      final current = _turnEmphasis
          ? _buildFollowViewport(zoom: 16.5, pitch: 35.0)
          : _buildFollowViewport(zoom: 15.0, pitch: 0.0);
      _viewport = current;
    });
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

  Future<Uint8List> _buildOriginPuckLikeImageBytes({int sizePx = 96}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final w = sizePx.toDouble();
    final h = sizePx.toDouble();

    // Puck-like dot: subtle shadow + white ring + light-blue fill.
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = ui.PaintingStyle.fill;

    final ringPaint = ui.Paint()
      ..color = Colors.white.withValues(alpha: 0.98)
      ..style = ui.PaintingStyle.fill;

    final fillPaint = ui.Paint()
      ..color = const Color(0xFF7FB3FF)
      ..style = ui.PaintingStyle.fill;

    final cx = w / 2.0;
    final cy = h / 2.0;

    final ringRadius = w * 0.34;
    final fillRadius = w * 0.26;

    // Shadow slightly down/right.
    canvas.drawCircle(
      ui.Offset(cx + (w * 0.03), cy + (h * 0.04)),
      ringRadius,
      shadowPaint,
    );

    // White ring background.
    canvas.drawCircle(ui.Offset(cx, cy), ringRadius, ringPaint);

    // Inner light-blue fill.
    canvas.drawCircle(ui.Offset(cx, cy), fillRadius, fillPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(sizePx, sizePx);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _ensureRoutePins() async {
    final mgr = _annotationManager;
    final coords = _fullRouteCoords;
    if (mgr == null || coords.length < 2) return;

    try {
      for (final pin in _routePins) {
        await mgr.delete(pin);
      }
      _routePins.clear();
    } catch (_) {}

    _pinImage ??= (await rootBundle.load(
      'lib/assets/images/pin.png',
    )).buffer.asUint8List();

    _originPuckLikeImage ??= await _buildOriginPuckLikeImageBytes(sizePx: 96);

    // Origin + destination pins
    final origin = coords.first;
    final dest = coords.last;

    try {
      final originPin = await mgr.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(origin.lng, origin.lat)),
          image: _originPuckLikeImage,
          iconSize: 0.22,
        ),
      );
      final destPin = await mgr.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(dest.lng, dest.lat)),
          image: _pinImage,
          iconSize: 0.32,
        ),
      );
      _routePins.addAll([originPin, destPin]);
    } catch (_) {
      // Ignore annotation failures.
    }
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;

    final lat1 = _degToRad(a.lat);
    final lat2 = _degToRad(b.lat);
    final dLat = lat2 - lat1;
    final dLon = _degToRad(b.lng - a.lng);

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLon = math.sin(dLon / 2.0);
    final aa =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    final c = 2.0 * math.atan2(math.sqrt(aa), math.sqrt(1.0 - aa));
    return earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String _formatInDistance(double? meters) {
    final d = meters;
    if (d == null) return 'In —';
    return 'In ${_formatDistance(d)}';
  }

  String _formatRoadSuffix(String? roadName) {
    final n = roadName?.trim();
    if (n == null || n.isEmpty) return '';
    return ' • $n';
  }

  String _formatDistance(double? meters) {
    final d = meters;
    if (d == null || d.isNaN || d.isInfinite) return '—';
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000.0).toStringAsFixed(1)} km';
  }

  void _openCommunityReportSheet() {
    if (!mounted) return;

    final gps = _lastGps;
    if (gps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS… try again in a moment.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool sending = false;

        // Lightweight rebuild on local `sending` changes without introducing
        // a new page/state object.
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submitWithState(FloodDepthLevel level) async {
              if (sending) return;
              setState(() => sending = true);
              try {
                HapticFeedback.selectionClick();
                await _communityReportService.submit(
                  location: gps,
                  depthLevel: level,
                );
                if (context.mounted) Navigator.of(context).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Report sent. Thank you for helping others.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to send report.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } finally {
                if (mounted) setState(() => sending = false);
              }
            }

            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            Widget depthTile({
              required FloodDepthLevel level,
              required IconData icon,
              required String helper,
            }) {
              final enabled = !sending;
              return Semantics(
                button: true,
                enabled: enabled,
                label: 'Report ${level.label}',
                child: Material(
                  color: colorScheme.surface,
                  elevation: enabled ? 1 : 0,
                  shadowColor: theme.shadowColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: enabled ? () => submitWithState(level) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: colorScheme.primary),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            level.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            helper,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Material(
                color: colorScheme.surface,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sending) const LinearProgressIndicator(minHeight: 3),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.water_drop_outlined,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Report flood depth',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.onSurface,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'One tap sends your report using current GPS.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.65),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.25,
                                  ),
                              children: [
                                depthTile(
                                  level: FloodDepthLevel.ankleDeep,
                                  icon: Icons.directions_walk,
                                  helper: 'Shallow water',
                                ),
                                depthTile(
                                  level: FloodDepthLevel.kneeDeep,
                                  icon: Icons.accessibility_new,
                                  helper: 'Use caution',
                                ),
                                depthTile(
                                  level: FloodDepthLevel.waistDeep,
                                  icon: Icons.person,
                                  helper: 'High risk',
                                ),
                                depthTile(
                                  level: FloodDepthLevel.chestDeep,
                                  icon: Icons.person_outline,
                                  helper: 'Very dangerous',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Only report if safe to do so.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  final String instruction;
  final String secondary;
  final String? nextInstruction;
  final String? modifier;

  const _InstructionBanner({
    required this.instruction,
    required this.secondary,
    required this.nextInstruction,
    required this.modifier,
  });

  IconData _modifierIcon(String? modifier) {
    final m = (modifier ?? '').toLowerCase();
    if (m.contains('left')) return Icons.turn_left;
    if (m.contains('right')) return Icons.turn_right;
    if (m.contains('uturn')) return Icons.u_turn_left;
    if (m.contains('straight')) return Icons.straight;
    return Icons.navigation;
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B7D5A);
    final thenText =
        (nextInstruction != null && nextInstruction!.trim().isNotEmpty)
        ? 'Then ${nextInstruction!.trim()}'
        : null;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _modifierIcon(modifier),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (thenText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      thenText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrivingDetailsSheet extends StatelessWidget {
  final double minSize;
  final double initialSize;
  final double maxSize;
  final double? remainingDistanceMeters;
  final VoidCallback onEnd;

  const _DrivingDetailsSheet({
    required this.minSize,
    required this.initialSize,
    required this.maxSize,
    required this.remainingDistanceMeters,
    required this.onEnd,
  });

  String _formatDistance(double? meters) {
    final d = meters;
    if (d == null || d.isNaN || d.isInfinite) return '—';
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000.0).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: minSize,
      initialChildSize: initialSize,
      maxChildSize: maxSize,
      builder: (context, scrollController) {
        return Material(
          elevation: 14,
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADADA),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining distance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDistance(remainingDistanceMeters),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'End navigation',
                        onPressed: onEnd,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                  children: const [
                    // Placeholder: future driving details can go here.
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedometerChip extends StatelessWidget {
  final double? speedKph;

  const _SpeedometerChip({required this.speedKph});

  @override
  Widget build(BuildContext context) {
    final s = speedKph;
    final display = (s == null || s.isNaN || s.isInfinite)
        ? '—'
        : s.round().toString();
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              display,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'km/h',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightButtonGroup extends StatelessWidget {
  final bool isNorthUp;
  final VoidCallback onToggleNorthUp;
  final bool isFloodEnabled;
  final VoidCallback onToggleFlood;
  final VoidCallback onCommunityReport;
  final bool rerouteInFlight;
  final VoidCallback onReroute;

  const _RightButtonGroup({
    required this.isNorthUp,
    required this.onToggleNorthUp,
    required this.isFloodEnabled,
    required this.onToggleFlood,
    required this.onCommunityReport,
    required this.rerouteInFlight,
    required this.onReroute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'fab-reroute-driving',
          backgroundColor: Colors.white,
          mini: true,
          elevation: 2,
          onPressed: rerouteInFlight ? null : onReroute,
          child: Icon(
            Icons.alt_route,
            color: rerouteInFlight ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'fab-compass-driving',
          backgroundColor: Colors.white,
          mini: true,
          elevation: 2,
          onPressed: onToggleNorthUp,
          child: Icon(
            Icons.explore,
            color: isNorthUp ? const Color(0xFF0B7D5A) : Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'fab-community-report-driving',
          backgroundColor: Colors.white,
          mini: true,
          elevation: 2,
          onPressed: onCommunityReport,
          child: const Icon(Icons.campaign_outlined, color: Color(0xFF0B7D5A)),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'fab-flood-driving',
          backgroundColor: Colors.white,
          mini: true,
          elevation: 2,
          onPressed: onToggleFlood,
          child: Icon(
            Icons.waves,
            color: isFloodEnabled ? const Color(0xFF0B7D5A) : Colors.grey,
          ),
        ),
      ],
    );
  }
}
