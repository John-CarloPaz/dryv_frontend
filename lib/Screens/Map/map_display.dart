import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Services/backend_routing_service.dart';
import 'package:dryvmobapp/Services/location_service.dart';
import 'package:dryvmobapp/Services/app_file_logger.dart';
import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Screens/Navigation/route_preview_screen.dart';
import 'package:dryvmobapp/Services/bottom_nav_visibility.dart';
import 'package:dryvmobapp/Widgets/grouped_buttons.dart';
import 'package:dryvmobapp/Widgets/location_details.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/Widgets/safest_route_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  late MapboxMap mapboxMap;
  PointAnnotationManager? annotationManager;
  final List<PointAnnotation> addedAnnotations = [];
  final TextEditingController _searchController = TextEditingController();

  PersistentBottomSheetController? _locationSheetController;

  _SelectedPlace? _selectedPlace;

  final double defaultLng = 120.592083;
  final double defaultLat = 15.158430;

  bool mapboxMapInitialized = false;
  bool _userLocationEnabled = false;
  ViewportState? _viewport;

  bool _pendingLocationAutoRetry = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    final camera = CameraOptions(
      center: Point(coordinates: Position(defaultLng, defaultLat)),
      zoom: 12,
    );

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: camera,
            viewport: _viewport,
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(
              onTap: _openSearchScreen,
              controller: _searchController,
              hintText: _searchController.text.isNotEmpty
                  ? _searchController.text
                  : null,
            ),
          ),
          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: GroupedButtons(
                mapboxMap: mapboxMap,
                isUserLocationEnabled: _userLocationEnabled,
                onToggleUserLocation: _toggleUserLocation,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Create annotation manager for point annotations
    annotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    setState(() => mapboxMapInitialized = true);
  }

  Future<void> _toggleUserLocation() async {
    if (!mapboxMapInitialized) return;

    // If GPS/Location Services are off, Mapbox won't receive location updates.
    final servicesEnabled = await LocationService.ensureLocationServicesEnabled(
      context,
    );
    if (!mounted) return;
    if (!servicesEnabled) {
      // User may have been sent to settings; auto-retry once on resume.
      _pendingLocationAutoRetry = true;
      return;
    }

    // First tap: ask for permission, then enable Mapbox location.
    if (!_userLocationEnabled) {
      final granted = await LocationService.ensureLocationPermission(context);
      if (!mounted) return;
      if (!granted) {
        // If permission was denied permanently, user likely went to settings.
        _pendingLocationAutoRetry = true;
        return;
      }

      await _enableAndFollowUser();

      return;
    }

    // Subsequent taps: re-center/follow the puck again (Mapbox-only).
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    setState(() {
      _viewport = FollowPuckViewportState(
        zoom: 15.0,
        pitch: 0.0,
        bearing: const FollowPuckViewportStateBearingHeading(),
      );
    });
  }

  Future<void> _enableAndFollowUser() async {
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    if (!mounted) return;
    setState(() {
      _userLocationEnabled = true;
      _viewport = FollowPuckViewportState(
        zoom: 15.0,
        pitch: 0.0,
        bearing: const FollowPuckViewportStateBearingHeading(),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_pendingLocationAutoRetry) return;
    _pendingLocationAutoRetry = false;

    // Don't show dialogs on resume; only proceed if both are already enabled.
    () async {
      if (!mounted || !mapboxMapInitialized) return;
      final gpsOn = await LocationService.isLocationServicesEnabled();
      final hasPermission = await LocationService.hasLocationPermission();
      if (!gpsOn || !hasPermission) return;
      await _enableAndFollowUser();
    }();
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SearchScreen(initialQuery: _searchController.text),
      ),
    );

    if (result != null && mounted) {
      final double lng = result['lng'];
      final double lat = result['lat'];
      final String name = result['name'];
      final String address = (result['address'] ?? '').toString();

      _selectedPlace = _SelectedPlace(
        lat: lat,
        lng: lng,
        name: name,
        address: address,
      );

      // Update the search bar's controller so the chosen location is displayed
      _searchController.text = name;

      // Fly camera to location
      await mapboxMap.flyTo(
        CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 14),
        MapAnimationOptions(duration: 1000),
      );

      // Remove previous annotations
      for (var annotation in addedAnnotations) {
        await annotationManager?.delete(annotation);
      }
      addedAnnotations.clear();

      final ByteData bytes = await rootBundle.load('lib/assets/images/pin.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      final newAnnotation = await annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          image: imageData,
          iconSize: 0.3,
        ),
      );

      addedAnnotations.add(newAnnotation);

      if (!mounted) return;
      _showSelectedPlaceDetails();
    }
  }

  void _showSelectedPlaceDetails() {
    final selected = _selectedPlace;
    if (!mounted || selected == null) return;

    _locationSheetController?.close();

    final releaseBottomNav = BottomNavVisibility.acquireHide();
    _locationSheetController = Scaffold.of(context).showBottomSheet(
      (ctx) {
        return LocationDetailsSheet(
          name: selected.name,
          address: selected.address,
          destination: LatLng(lat: selected.lat, lng: selected.lng),
          onNavigate: () async {
            _locationSheetController?.close();
            _locationSheetController = null;

            await _requestAndPreviewBackendRoute(
              destination: LatLng(lat: selected.lat, lng: selected.lng),
              destinationName: selected.name,
            );

            if (!mounted) return;
            _showSelectedPlaceDetails();
          },
          onSave: () {
            // Implement save/bookmark behavior
            _locationSheetController?.close();
          },
          onClose: () {
            // When the user closes the sheet, remove the annotation and clear
            // the search field
            _selectedPlace = null;
            _locationSheetController?.close();
            for (var annotation in addedAnnotations) {
              annotationManager?.delete(annotation);
            }
            addedAnnotations.clear();
            _searchController.clear();
          },
        );
      },
      backgroundColor: Colors.white,
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      enableDrag: false,
    );

    _locationSheetController?.closed.whenComplete(() {
      releaseBottomNav();
      if (mounted) {
        _locationSheetController = null;
      }
    });
  }

  Future<void> _requestAndPreviewBackendRoute({
    required LatLng destination,
    required String destinationName,
  }) async {
    if (!mounted) return;

    // Require location services + permission (origin must be correct for safety).
    final servicesEnabled = await LocationService.ensureLocationServicesEnabled(
      context,
    );
    if (!mounted) return;
    if (!servicesEnabled) return;
    final permissionGranted = await LocationService.ensureLocationPermission(
      context,
    );
    if (!mounted) return;
    if (!permissionGranted) return;

    // 1) Obtain an origin (current device location) to send to backend.
    final originMap = await LocationService.getLastKnownLocation();
    if (!mounted) return;
    if (originMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to determine your current location. Enable location and try again.',
          ),
        ),
      );
      return;
    }

    final origin = LatLng(lat: originMap['lat']!, lng: originMap['lng']!);

    // 2) Build backend endpoint from env; fail fast if not configured.
    final baseUrl = dotenv.env['API_BASE_URL'];
    final fallbackEndpoint = (baseUrl == null || baseUrl.trim().isEmpty)
        ? null
        : '${baseUrl.replaceAll(RegExp(r"/+$"), "")}/route/safe';

    final endpoint =
        (dotenv.env['DRYV_SAFEST_ROUTE_URL']?.trim().isNotEmpty == true)
        ? dotenv.env['DRYV_SAFEST_ROUTE_URL']
        : fallbackEndpoint;

    if (endpoint == null || endpoint.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backend route URL not configured. Set API_BASE_URL or DRYV_SAFEST_ROUTE_URL in .env',
          ),
        ),
      );
      return;
    }

    final service = BackendRoutingService(
      safestRouteEndpoint: Uri.parse(endpoint),
    );

    AppFileLogger.instance.info(
      'Navigate tapped: using backend endpoint=$endpoint',
    );

    // 3) Show full-screen loading UI while waiting for backend response.
    // We push the overlay route *without awaiting* and then run the request.
    Navigator.of(context).push(
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

    AppFileLogger.instance.info('Showing SafestRouteLoadingOverlay');

    // Ensure the overlay is on the stack before we start, so a `pop()` closes it.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    await _fetchRouteWhileShowingLoader(
      service: service,
      origin: origin,
      destination: destination,
      destinationName: destinationName,
    );
  }

  /// NOTE: This method is split out so we can show a full-screen loading overlay
  /// while the backend request is inflight.
  Future<void> _fetchRouteWhileShowingLoader({
    required BackendRoutingService service,
    required LatLng origin,
    required LatLng destination,
    required String destinationName,
  }) async {
    late final BackendApprovedRoute approved;
    try {
      approved = await service.fetchSafestRoute(
        origin: origin,
        destination: destination,
      );
    } on BackendRoutingException catch (e) {
      AppFileLogger.instance.warn(
        'Safest route backend exception: ${e.code} ${e.message}',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (e) {
      AppFileLogger.instance.error('Safest route unexpected error', err: e);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to calculate safest route: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    // 4) Open Flutter-native route preview + driving flow.
    AppFileLogger.instance.info('Opening Flutter RoutePreviewScreen');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutePreviewScreen(
          approved: approved,
          originLabel: 'Your location',
          destinationLabel: destinationName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }
}

class _SelectedPlace {
  final double lat;
  final double lng;
  final String name;
  final String address;

  const _SelectedPlace({
    required this.lat,
    required this.lng,
    required this.name,
    required this.address,
  });
}
