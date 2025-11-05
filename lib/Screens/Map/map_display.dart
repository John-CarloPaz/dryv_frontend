import 'package:dryvmobapp/Screens/Search/search_screen.dart';
import 'package:dryvmobapp/Widgets/layers_button.dart';
import 'package:dryvmobapp/Widgets/search_bar.dart';
import 'package:dryvmobapp/Widgets/location_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap mapboxMap;
  PointAnnotationManager? annotationManager;
  List<PointAnnotation> addedAnnotations = [];
  final TextEditingController _searchController = TextEditingController();

  final defaultLng = 120.592083;
  final defaultLat = 15.158430;

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
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SearchBarWidget(
              onTap: _openSearchScreen,
              controller: _searchController,
              hintText: _searchController.text.isNotEmpty ? _searchController.text : null,
            ),
          ),
          if (mapboxMapInitialized)
            Positioned(
              top: 120,
              right: 14,
              child: LayerButtonWidget(
                mapboxMap: mapboxMap,
                onStyleChanged: _reapplyRealtimeFloodLayer,
              ),
            ),
        ],
      ),
    );
  }

  bool mapboxMapInitialized = false;
  Timer? _floodTimer;
  String? _lastFloodGeoJson;
  Duration _floodPollInterval = const Duration(seconds: 2);
  DateTime? _lastFloodUpdated;

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Create annotation manager for point annotations
    annotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    setState(() => mapboxMapInitialized = true);

    // Add realtime flood layer from fake API (or backend when available)
    // Start periodic polling to keep the realtime flood layer up-to-date.
    _startRealtimeFloodUpdates();
  }

  void _startRealtimeFloodUpdates() {
    _floodTimer?.cancel();
    _fetchAndApplyRealtimeFloodData();
    _floodTimer = Timer.periodic(_floodPollInterval, (_) => _fetchAndApplyRealtimeFloodData());
  }

  /// Re-applies the realtime flood layer after style changes or layer toggles.
  /// This ensures the realtime flood data is always visible regardless of other layer changes.
  Future<void> _reapplyRealtimeFloodLayer() async {
    if (!mapboxMapInitialized) return;
    
    // If we have cached flood data, immediately re-apply it
    if (_lastFloodGeoJson != null) {
      await _applyFloodDataToMap(_lastFloodGeoJson!);
    } else {
      // Otherwise fetch fresh data
      await _fetchAndApplyRealtimeFloodData();
    }
  }

  /// Applies flood GeoJSON data to the map by creating/updating the source and layers.
  Future<void> _applyFloodDataToMap(String geojson) async {
    if (!mapboxMapInitialized) return;

    try {
      // Check if source exists
      final exists = await mapboxMap.style.styleSourceExists('realtime-flood-source');
      
      if (exists) {
        // Remove existing layers first
        final layerIds = ['realtime-flood-layer', 'realtime-flood-outline'];
        for (final id in layerIds) {
          final layerExists = await mapboxMap.style.styleLayerExists(id);
          if (layerExists) {
            try {
              await mapboxMap.style.removeStyleLayer(id);
            } catch (e) {
              debugPrint('Failed to remove layer $id: $e');
            }
          }
        }

        // Remove the source
        try {
          await mapboxMap.style.removeStyleSource('realtime-flood-source');
        } catch (e) {
          debugPrint('Failed to remove source realtime-flood-source: $e');
        }
      }

      // Add fresh source
      await mapboxMap.style.addSource(GeoJsonSource(
        id: 'realtime-flood-source',
        data: geojson,
      ));

      // Add fill layer for realtime flooded polygons
      await mapboxMap.style.addLayer(FillLayer(
        id: 'realtime-flood-layer',
        sourceId: 'realtime-flood-source',
        fillColor: Colors.cyan.withValues(alpha: 0.35).toARGB32(),
      ));

      // Add outline layer for clarity
      await mapboxMap.style.addLayer(LineLayer(
        id: 'realtime-flood-outline',
        sourceId: 'realtime-flood-source',
        lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
        lineWidth: 1.0,
      ));

      debugPrint('Realtime flood layer applied successfully at ${DateTime.now()}');
    } catch (e, st) {
      debugPrint('Failed to apply realtime flood data to map: $e\n$st');
    }
  }

  Future<void> _fetchAndApplyRealtimeFloodData() async {
    debugPrint("${DateTime.now()} Fetching realtime flood data...");
    // URL to the fake API JSON (raw GitHub URL)
    const url = 'https://raw.githubusercontent.com/John-CarloPaz/fake-apis/main/flooded-polygons.json';

    // Ensure map is ready
    if (!mapboxMapInitialized) return;

    try {
  // Append a timestamp to avoid potential caching of the raw GitHub URL
  final fetchUrl = '$url?_ts=${DateTime.now().millisecondsSinceEpoch}';
  final resp = await http.get(Uri.parse(fetchUrl));
      if (resp.statusCode != 200) {
        debugPrint('Realtime flood API returned ${resp.statusCode}');
        return;
      }

      final String geojson = resp.body;

  // Avoid unnecessary updates when payload didn't change
  if (_lastFloodGeoJson != null && _lastFloodGeoJson == geojson) return;

      // If the source already exists, update it instead of re-adding
      final exists = await mapboxMap.style.styleSourceExists('realtime-flood-source');
      if (!exists) {
        await mapboxMap.style.addSource(GeoJsonSource(id: 'realtime-flood-source', data: geojson));

        // Fill layer for realtime flooded polygons - different palette from tileset flood
        await mapboxMap.style.addLayer(FillLayer(
          id: 'realtime-flood-layer',
          sourceId: 'realtime-flood-source',
          fillColor: Colors.cyan.withValues(alpha: 0.35).toARGB32(),
        ));

        // Optional outline layer for clarity
        await mapboxMap.style.addLayer(LineLayer(
          id: 'realtime-flood-outline',
          sourceId: 'realtime-flood-source',
          lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
          lineWidth: 1.0,
        ));
      } else {
        // If the source exists we remove layers that reference it first,
        // then remove & re-add the source. This avoids a "source is in use" error.
        final layerIds = ['realtime-flood-layer', 'realtime-flood-outline'];
        for (final id in layerIds) {
          final layerExists = await mapboxMap.style.styleLayerExists(id);
          if (layerExists) {
            try {
              await mapboxMap.style.removeStyleLayer(id);
            } catch (e) {
              debugPrint('Failed to remove layer $id: $e');
            }
          }
        }

        final sourceExistsNow = await mapboxMap.style.styleSourceExists('realtime-flood-source');
        if (sourceExistsNow) {
          try {
            await mapboxMap.style.removeStyleSource('realtime-flood-source');
          } catch (e) {
            debugPrint('Failed to remove source realtime-flood-source: $e');
          }
        }

        await mapboxMap.style.addSource(GeoJsonSource(id: 'realtime-flood-source', data: geojson));

        // Re-add layers so they use the fresh source
        await mapboxMap.style.addLayer(FillLayer(
          id: 'realtime-flood-layer',
          sourceId: 'realtime-flood-source',
          fillColor: Colors.cyan.withValues(alpha: 0.35).toARGB32(),
        ));

        await mapboxMap.style.addLayer(LineLayer(
          id: 'realtime-flood-outline',
          sourceId: 'realtime-flood-source',
          lineColor: Colors.cyan.withValues(alpha: 0.9).toARGB32(),
          lineWidth: 1.0,
        ));
      }
      // Update local state so the Flutter UI can react if needed.
      if (mounted) {
        setState(() {
          _lastFloodGeoJson = geojson;
          _lastFloodUpdated = DateTime.now();
        });
        debugPrint('Realtime flood source updated at $_lastFloodUpdated');
      }
    } catch (e, st) {
      debugPrint('Failed to load realtime flood data: $e\n$st');
    }
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchScreen(initialQuery: _searchController.text)),
    );

    if (result != null && mounted) {
      final double lng = result['lng'];
      final double lat = result['lat'];
      final String name = result['name'];

      // update the search bar's controller so the chosen location is displayed
      _searchController.text = name;

      // Fly camera to location
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 1000),
      );

      // Remove previous annotations
      for (var annotation in addedAnnotations) {
        annotationManager!.delete(annotation);
      }
      addedAnnotations.clear();

      final ByteData bytes = await rootBundle.load('lib/assets/images/pin.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      final newAnnotation = await annotationManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        image: imageData,
        iconSize: 0.3,
        // textField: name,
        // textSize: 14,
        // textOffset: [0, 2],
      ));

      addedAnnotations.add(newAnnotation);
            
      // show a persistent bottom sheet (so the map remains interactive)
      if (!mounted) return;
  PersistentBottomSheetController? sheetController;
  sheetController = Scaffold.of(context).showBottomSheet((ctx) {
        return LocationDetailsSheet(
          name: name,
          address: result['address'] ?? '',
          onNavigate: () {
            // implement navigation action (open external maps or start route)
            sheetController?.close();
          },
          onSave: () {
            // implement save/bookmark behavior
            sheetController?.close();
          },
          onClose: () {
            // when the user closes the sheet, remove the annotation and clear the search
            sheetController?.close();
            for (var annotation in addedAnnotations) {
              annotationManager!.delete(annotation);
            }
            addedAnnotations.clear();
            _searchController.clear();
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _floodTimer?.cancel();
    super.dispose();
  }
}
