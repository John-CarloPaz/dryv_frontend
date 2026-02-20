import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:dryvmobapp/Services/community_flood_overlay_service.dart';
import 'package:dryvmobapp/Services/realtime_flood_overlay_state.dart';

class FloodOverlayVisibility {
  final bool floodMap;
  final bool realtimeFlood;

  const FloodOverlayVisibility({
    required this.floodMap,
    required this.realtimeFlood,
  });

  bool get any => floodMap || realtimeFlood;
}

class LayerButtonWidget extends StatefulWidget {
  final MapboxMap mapboxMap;
  final VoidCallback? onStyleChanged;
  final ValueChanged<FloodOverlayVisibility>? onFloodOverlayVisibilityChanged;
  const LayerButtonWidget({
    super.key,
    required this.mapboxMap,
    this.onStyleChanged,
    this.onFloodOverlayVisibilityChanged,
  });

  @override
  State<LayerButtonWidget> createState() => _LayerButtonWidgetState();
}

class _LayerButtonWidgetState extends State<LayerButtonWidget> {
  bool _isFloodLayerVisible = false;
  bool _isRealtimeFloodLayerVisible = false;
  bool _isCommunityReportedFloodsVisible = false;

  final CommunityFloodOverlayService _communityFloodOverlayService =
      CommunityFloodOverlayService();

  void _notifyOverlayVisibility() {
    widget.onFloodOverlayVisibilityChanged?.call(
      FloodOverlayVisibility(
        floodMap: _isFloodLayerVisible,
        realtimeFlood: _isRealtimeFloodLayerVisible,
      ),
    );
  }

  bool _looksLikeLabelLayer(String id, String? type) {
    final t = (type ?? '').toLowerCase();
    if (t == 'symbol') return true;
    final lower = id.toLowerCase();
    return lower.contains('label') ||
        lower.contains('poi') ||
        lower.contains('place') ||
        lower.contains('settlement');
  }

  bool _looksLikeLocationLayer(String id) {
    final lower = id.toLowerCase();
    return lower.contains('location') ||
        lower.contains('puck') ||
        lower.contains('mapbox-location');
  }

  Future<String?> _findOverlayAnchorLayerId() async {
    // We want flood overlays below map labels/POIs and below the location puck.
    // On classic styles (streets/satellite-streets), `slot` is ignored, so we
    // must insert layers explicitly using LayerPosition.
    final layers = await widget.mapboxMap.style.getStyleLayers();

    int? firstLabelIndex;
    int? firstLocationIndex;

    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i] as dynamic;
      final id = (layer.id as String?) ?? '';
      if (id.isEmpty) continue;

      final type = layer.type as String?;

      if (firstLabelIndex == null && _looksLikeLabelLayer(id, type)) {
        firstLabelIndex = i;
      }
      if (firstLocationIndex == null && _looksLikeLocationLayer(id)) {
        firstLocationIndex = i;
      }

      if (firstLabelIndex != null && firstLocationIndex != null) break;
    }

    int? anchorIndex;
    if (firstLabelIndex != null && firstLocationIndex != null) {
      anchorIndex = firstLabelIndex < firstLocationIndex
          ? firstLabelIndex
          : firstLocationIndex;
    } else {
      anchorIndex = firstLabelIndex ?? firstLocationIndex;
    }

    if (anchorIndex == null) return null;
    final anchor = layers[anchorIndex] as dynamic;
    return anchor.id as String?;
  }

  Future<LayerPosition?> _overlayBaseLayerPosition() async {
    final anchorId = await _findOverlayAnchorLayerId();
    if (anchorId == null || anchorId.isEmpty) return null;
    return LayerPosition(below: anchorId);
  }

  void _showMutualExclusionSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLayerDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final floodDisabled = _isRealtimeFloodLayerVisible;
        final realtimeDisabled = _isFloodLayerVisible;

        final textTheme = Theme.of(sheetContext).textTheme;
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final sheetHeight = MediaQuery.of(sheetContext).size.height * 0.78;

        return SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Layers',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Map style',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          _changeMapStyle('mapbox://styles/mapbox/streets-v12');
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Streets'),
                        style: FilledButton.styleFrom(
                          minimumSize: const ui.Size(0, 56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          _changeMapStyle(
                            'mapbox://styles/mapbox/satellite-streets-v12',
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.terrain_outlined),
                        label: const Text('Satellite'),
                        style: FilledButton.styleFrom(
                          minimumSize: const ui.Size(0, 56),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Overlays',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _LayerToggleCard(
                  icon: Icons.water_outlined,
                  title: 'Flood map',
                  subtitle: floodDisabled
                      ? 'Turn off “Realtime flood” to enable'
                      : 'Pampanga flood tileset overlay',
                  value: _isFloodLayerVisible,
                  enabled: !floodDisabled,
                  onChanged: floodDisabled
                      ? null
                      : (value) async {
                          await _toggleFloodLayer();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                ),
                const SizedBox(height: 10),
                _LayerToggleCard(
                  icon: Icons.waves_outlined,
                  title: 'Realtime flood',
                  subtitle: realtimeDisabled
                      ? 'Turn off “Flood map” to enable'
                      : 'Live risk overlay (low → high)',
                  value: _isRealtimeFloodLayerVisible,
                  enabled: !realtimeDisabled,
                  onChanged: realtimeDisabled
                      ? null
                      : (value) async {
                          await _toggleRealtimeFloodLayer();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                ),
                const SizedBox(height: 10),
                _LayerToggleCard(
                  icon: Icons.people_alt_outlined,
                  title: 'Community reported floods',
                  subtitle: 'Reported flooded roads (community)',
                  value: _isCommunityReportedFloodsVisible,
                  enabled: true,
                  onChanged: (value) async {
                    await _toggleCommunityReportedFloods();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
  }

  Future<void> _changeMapStyle(String styleUrl) async {
    await widget.mapboxMap.style.setStyleURI(styleUrl);
    // Notify parent so it can re-apply sources/layers that were removed by style change
    widget.onStyleChanged?.call();

    // Re-apply any overlays that were enabled prior to the style change.
    // Style changes reset runtime-added sources/layers.
    await _reapplyEnabledOverlays();
  }

  Future<void> _reapplyEnabledOverlays() async {
    // Enforce mutual exclusivity (defensive: older builds may have allowed both).
    if (_isFloodLayerVisible && _isRealtimeFloodLayerVisible) {
      setState(() => _isRealtimeFloodLayerVisible = false);
      _notifyOverlayVisibility();
    }
    if (_isFloodLayerVisible) {
      await _addFloodLayer();
    }
    if (_isRealtimeFloodLayerVisible) {
      await _addRealtimeFloodLayer();
    }

    if (_isCommunityReportedFloodsVisible) {
      try {
        await _communityFloodOverlayService.setEnabled(
          mapboxMap: widget.mapboxMap,
          enabled: true,
          layerPosition: await _communityOverlayLayerPosition(),
        );
      } catch (_) {
        // If community overlay fails to re-apply (e.g., network/auth), keep the
        // toggle state but don't crash the style change.
      }
    }
  }

  Future<LayerPosition?> _communityOverlayLayerPosition() async {
    final style = widget.mapboxMap.style;

    if (_isRealtimeFloodLayerVisible) {
      const topRealtimeLayerId = 'realtime-flood-layer-3';
      final exists = await style.styleLayerExists(topRealtimeLayerId);
      if (exists) return LayerPosition(above: topRealtimeLayerId);
    }

    if (_isFloodLayerVisible) {
      const topFloodLayerId = 'flood-layer-var3';
      final exists = await style.styleLayerExists(topFloodLayerId);
      if (exists) return LayerPosition(above: topFloodLayerId);
    }

    return _overlayBaseLayerPosition();
  }

  Future<void> _toggleCommunityReportedFloods() async {
    final mapboxMap = widget.mapboxMap;
    final nextEnabled = !_isCommunityReportedFloodsVisible;

    try {
      await _communityFloodOverlayService.setEnabled(
        mapboxMap: mapboxMap,
        enabled: nextEnabled,
        layerPosition: nextEnabled
            ? await _communityOverlayLayerPosition()
            : null,
      );

      if (!mounted) return;
      setState(() => _isCommunityReportedFloodsVisible = nextEnabled);
      // notify parent to re-apply overlays if needed
      widget.onStyleChanged?.call();
    } catch (e, st) {
      debugPrint('❌ Failed to toggle community flooded roads overlay: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load community reported floods'),
        ),
      );
    }
  }

  Future<void> _removeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;
    for (final id in [
      'flood-layer-var1',
      'flood-layer-var2',
      'flood-layer-var3',
    ]) {
      final exists = await mapboxMap.style.styleLayerExists(id);
      if (exists) await mapboxMap.style.removeStyleLayer(id);
    }

    final sourceExists = await mapboxMap.style.styleSourceExists(
      'flood_source',
    );
    if (sourceExists) await mapboxMap.style.removeStyleSource('flood_source');
  }

  Future<void> _addFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    // Ensure no stale source/layers exist.
    await _removeFloodLayer();

    // Hosted vector tileset for Pampanga flood map
    await mapboxMap.style.addSource(
      VectorSource(
        id: 'flood_source',
        url: 'mapbox://johncarlo123.pampanga-flood-map',
      ),
    );

    final basePosition = await _overlayBaseLayerPosition();

    // Categorized layers by `Var` property (note uppercase V)
    final floodVar1 = FillLayer(
      id: 'flood-layer-var1',
      sourceId: 'flood_source',
      sourceLayer: 'flood',
      filter: [
        '==',
        ['get', 'Var'],
        1,
      ],
      fillColor: Colors.yellow.withValues(alpha: .6).toARGB32(),
    );
    if (basePosition != null) {
      await mapboxMap.style.addLayerAt(floodVar1, basePosition);
    } else {
      await mapboxMap.style.addLayer(floodVar1);
    }

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: 'flood-layer-var2',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: [
          '==',
          ['get', 'Var'],
          2,
        ],
        fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: 'flood-layer-var1'),
    );

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: 'flood-layer-var3',
        sourceId: 'flood_source',
        sourceLayer: 'flood',
        filter: [
          '==',
          ['get', 'Var'],
          3,
        ],
        fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: 'flood-layer-var2'),
    );
  }

  Future<void> _toggleFloodLayer() async {
    if (_isFloodLayerVisible) {
      await _removeFloodLayer();

      setState(() => _isFloodLayerVisible = false);
      _notifyOverlayVisibility();
      // notify parent to re-apply overlays if needed
      widget.onStyleChanged?.call();
    } else {
      if (_isRealtimeFloodLayerVisible) {
        _showMutualExclusionSnackBar(
          'Turn off Realtime Flood Layer before enabling Flood Map Layer.',
        );
        return;
      }
      try {
        await _addFloodLayer();

        setState(() => _isFloodLayerVisible = true);
        _notifyOverlayVisibility();
        debugPrint('✅ Flood tileset layer loaded (Pampanga).');
      } catch (e, st) {
        debugPrint('❌ Failed to load flood tileset layer: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add flood tileset layer')),
        );
      }
    }
  }

  Future<void> _toggleRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const outlineLayerId = 'realtime-flood-outline';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';
    final fillLayerIds = [fillLayerId1, fillLayerId2, fillLayerId3];

    if (_isRealtimeFloodLayerVisible) {
      // Remove realtime flood layers + source
      for (final id in [...fillLayerIds, outlineLayerId]) {
        final exists = await mapboxMap.style.styleLayerExists(id);
        if (exists) await mapboxMap.style.removeStyleLayer(id);
      }

      final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
      if (sourceExists) await mapboxMap.style.removeStyleSource(sourceId);

      setState(() => _isRealtimeFloodLayerVisible = false);
      _notifyOverlayVisibility();
      widget.onStyleChanged?.call();
      RealtimeFloodOverlayState.setEnabled(false);
      return;
    }

    if (_isFloodLayerVisible) {
      _showMutualExclusionSnackBar(
        'Turn off Flood Map Layer before enabling Realtime Flood Layer.',
      );
      return;
    }

    try {
      await _addRealtimeFloodLayer();
      setState(() => _isRealtimeFloodLayerVisible = true);
      _notifyOverlayVisibility();
      debugPrint('✅ Realtime flood layer loaded from realtime tileset.');
      widget.onStyleChanged?.call();
      RealtimeFloodOverlayState.setEnabled(true);
    } catch (ePrimary, stPrimary) {
      debugPrint(
        '❌ Failed to load realtime flood tileset: $ePrimary\n$stPrimary',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add realtime flood layer')),
      );
    }
  }

  Future<void> _removeRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const outlineLayerId = 'realtime-flood-outline';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';
    final fillLayerIds = [fillLayerId1, fillLayerId2, fillLayerId3];

    for (final id in [...fillLayerIds, outlineLayerId]) {
      final exists = await mapboxMap.style.styleLayerExists(id);
      if (exists) await mapboxMap.style.removeStyleLayer(id);
    }

    final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
    if (sourceExists) await mapboxMap.style.removeStyleSource(sourceId);
  }

  Future<void> _addRealtimeFloodLayer() async {
    final mapboxMap = widget.mapboxMap;

    const sourceId = 'realtime-flood-source';
    const fillLayerId1 = 'realtime-flood-layer-1';
    const fillLayerId2 = 'realtime-flood-layer-2';
    const fillLayerId3 = 'realtime-flood-layer-3';

    // Use hosted vector tileset for realtime flood view.
    // Keep in sync with MapService realtime flood tileset.
    const primaryTilesetUrl = 'mapbox://johncarlo123.dryv_tileset_1';

    await _removeRealtimeFloodLayer();

    await mapboxMap.style.addSource(
      VectorSource(id: sourceId, url: primaryTilesetUrl),
    );

    final basePosition = await _overlayBaseLayerPosition();

    final realtimeFill1 = FillLayer(
      id: fillLayerId1,
      sourceId: sourceId,
      sourceLayer: 'flooded',
      filter: [
        '==',
        ['get', 'risk_level'],
        1,
      ],
      fillColor: Colors.yellow.withValues(alpha: 0.6).toARGB32(),
    );
    if (basePosition != null) {
      await mapboxMap.style.addLayerAt(realtimeFill1, basePosition);
    } else {
      await mapboxMap.style.addLayer(realtimeFill1);
    }

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: fillLayerId2,
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: [
          '==',
          ['get', 'risk_level'],
          2,
        ],
        fillColor: Colors.orange.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: fillLayerId1),
    );

    await mapboxMap.style.addLayerAt(
      FillLayer(
        id: fillLayerId3,
        sourceId: sourceId,
        sourceLayer: 'flooded',
        filter: [
          '==',
          ['get', 'risk_level'],
          3,
        ],
        fillColor: Colors.red.withValues(alpha: 0.6).toARGB32(),
      ),
      LayerPosition(above: fillLayerId2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.white,
      heroTag: 'fab-layers',
      tooltip: 'Layers',
      mini: true,
      elevation: 2,
      onPressed: () => _showLayerDrawer(context),
      child: const Icon(Icons.layers, color: Colors.grey),
    );
  }
}

class _LayerToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _LayerToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveOnChanged = enabled ? onChanged : null;
    final leadingColor = enabled
        ? colorScheme.onSurface.withValues(alpha: 0.75)
        : colorScheme.onSurface.withValues(alpha: 0.35);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minVerticalPadding: 14,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: value
              ? colorScheme.primary.withValues(alpha: 0.14)
              : colorScheme.onSurface.withValues(alpha: 0.06),
          child: Icon(icon, color: value ? colorScheme.primary : leadingColor),
        ),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        trailing: Switch.adaptive(value: value, onChanged: effectiveOnChanged),
        onTap: effectiveOnChanged == null
            ? null
            : () => effectiveOnChanged(!value),
      ),
    );
  }
}
