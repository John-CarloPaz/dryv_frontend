import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Models/flood_nearby.dart';
import 'package:dryvmobapp/Services/flood_nearby_service.dart';
import 'package:dryvmobapp/Services/location_service.dart';
import 'package:dryvmobapp/Services/mapbox_directions_service.dart';
import 'package:flutter/material.dart';

enum _FloodRiskLevel { safe, low, moderate, high }

class LocationDetailsSheet extends StatefulWidget {
  final String name;
  final String? address;
  final LatLng? destination;
  final VoidCallback? onNavigate;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  const LocationDetailsSheet({
    super.key,
    this.name = '',
    this.address,
    this.destination,
    this.onNavigate,
    this.onSave,
    this.onClose,
  });

  @override
  State<LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<LocationDetailsSheet>
    with TickerProviderStateMixin {
  static const double _nearbyMetersThreshold = 200;

  bool _expanded = false;
  Future<int?>? _distanceMetersFuture;

  int? _maxRiskLevel;
  List<FloodedRoad> _nearbyFloodedRoads = const [];
  DateTime? _floodLastUpdatedAt;
  bool _floodLoading = false;
  bool _floodError = false;
  String? _floodErrorMessage;

  late final AnimationController _riskPulseController;
  late final Animation<double> _riskPulse;

  // Placeholders for now (to be replaced with backend data later).
  final DateTime _placeholderUpdatedAt = DateTime.now().subtract(
    const Duration(minutes: 17),
  );
  final String _placeholderRainForecast = 'Moderate Rainfall in 3 Hours';

  @override
  void initState() {
    super.initState();
    _distanceMetersFuture = _computeDistanceMeters();

    _initFloodNearby();

    _riskPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _riskPulse = CurvedAnimation(
      parent: _riskPulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _riskPulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocationDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldDest = oldWidget.destination;
    final newDest = widget.destination;

    final destChanged =
        oldDest?.lat != newDest?.lat || oldDest?.lng != newDest?.lng;
    if (destChanged) {
      _distanceMetersFuture = _computeDistanceMeters();
      _initFloodNearby();
    }
  }

  Future<void> _initFloodNearby() async {
    final destination = widget.destination;
    if (destination == null) return;

    setState(() {
      _floodLoading = true;
      _floodError = false;
      _floodErrorMessage = null;
    });

    try {
      final resp = await FloodNearbyService().fetchNearby(
        location: destination,
      );
      if (!mounted) return;

      final withinThreshold =
          resp.floodedRoads
              .where((r) => r.metersAway <= _nearbyMetersThreshold)
              .toList()
            ..sort((a, b) {
              final riskCmp = (b.riskLevel).compareTo(a.riskLevel);
              if (riskCmp != 0) return riskCmp;
              return (a.metersAway).compareTo(b.metersAway);
            });

      setState(() {
        _maxRiskLevel = resp.maxRiskLevel;
        _nearbyFloodedRoads = withinThreshold;
        _floodLastUpdatedAt = resp.lastUpdatedAt;
        _floodLoading = false;
        _floodError = false;
        _floodErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _maxRiskLevel = null;
        _nearbyFloodedRoads = const [];
        _floodLastUpdatedAt = null;
        _floodLoading = false;
        _floodError = true;
        _floodErrorMessage = e.toString();
      });
    }
  }

  Future<int?> _computeDistanceMeters() async {
    final destination = widget.destination;
    if (destination == null) return null;

    final originMap = await LocationService.getLastKnownLocation();
    if (originMap == null) return null;

    final origin = LatLng(lat: originMap['lat']!, lng: originMap['lng']!);

    return MapboxDirectionsService.fetchDrivingDistanceMeters(
      origin: origin,
      destination: destination,
    );
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
  }

  _FloodRiskLevel _riskFromMaxRiskLevel(int? maxRiskLevel) {
    final v = maxRiskLevel ?? 0;
    if (v <= 0) return _FloodRiskLevel.safe;
    if (v == 1) return _FloodRiskLevel.low;
    if (v == 2) return _FloodRiskLevel.moderate;
    return _FloodRiskLevel.high;
  }

  String _riskLabel(_FloodRiskLevel level) {
    switch (level) {
      case _FloodRiskLevel.safe:
        return 'Safe';
      case _FloodRiskLevel.low:
        return 'Low';
      case _FloodRiskLevel.moderate:
        return 'Moderate';
      case _FloodRiskLevel.high:
        return 'High';
    }
  }

  String _riskBadgeTextFromRiskLevelInt(int riskLevel) {
    final level = _riskFromMaxRiskLevel(riskLevel);
    return 'Risk ${riskLevel.clamp(0, 3)} • ${_riskLabel(level)}';
  }

  Color _riskBadgeBackgroundColor(_FloodRiskLevel level, Color safe) {
    switch (level) {
      case _FloodRiskLevel.safe:
        return safe.withValues(alpha: 0.14);
      case _FloodRiskLevel.low:
        return const Color(0xFFF1C40F).withValues(alpha: 0.18);
      case _FloodRiskLevel.moderate:
        return const Color(0xFFFF8C00).withValues(alpha: 0.18);
      case _FloodRiskLevel.high:
        return const Color(0xFFE74C3C).withValues(alpha: 0.18);
    }
  }

  Color _riskDotColor({required Color safe, required _FloodRiskLevel level}) {
    switch (level) {
      case _FloodRiskLevel.safe:
        return safe;
      case _FloodRiskLevel.low:
        return const Color(0xFFF1C40F); // yellow
      case _FloodRiskLevel.moderate:
        return const Color(0xFFFF8C00); // orange
      case _FloodRiskLevel.high:
        return const Color(0xFFE74C3C); // red
    }
  }

  String _riskText() {
    if (widget.destination == null) return 'Flood risk unavailable';
    if (_floodLoading) return 'Checking flood risk…';
    if (_floodError) {
      final msg = (_floodErrorMessage ?? '').trim();
      if (msg.isEmpty) return 'Flood risk unavailable';
      return msg;
    }

    final level = _riskFromMaxRiskLevel(_maxRiskLevel);
    switch (level) {
      case _FloodRiskLevel.safe:
        return 'Max flood risk within 200 meters: Safe';
      case _FloodRiskLevel.low:
        return 'Max flood risk within 200 meters: Low';
      case _FloodRiskLevel.moderate:
        return 'Max flood risk within 200 meters: Moderate';
      case _FloodRiskLevel.high:
        return 'Max flood risk within 200 meters: High';
    }
  }

  Widget _buildFloodedRoadsSection({
    required Color cDarkBlue,
    required Color cBlue,
    required Color cSafe,
  }) {
    if (widget.destination == null) return const SizedBox.shrink();

    final roads = _nearbyFloodedRoads;
    final bool showCards = !_floodLoading && !_floodError && _expanded;

    late final String title;
    Widget? trailing;

    if (_floodLoading) {
      title = 'Nearby flooded roads';
      trailing = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cDarkBlue.withValues(alpha: 0.65),
        ),
      );
    } else if (_floodError) {
      title = 'Nearby flooded roads';
      trailing = Text(
        'Unavailable',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cDarkBlue.withValues(alpha: 0.55),
        ),
      );
    } else {
      title = 'Nearby flooded roads (${roads.length})';
    }

    final displayed = roads.length <= 3 ? roads : roads.take(3).toList();
    final remaining = roads.length - displayed.length;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flood_outlined,
                size: 18,
                color: cDarkBlue.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cDarkBlue.withValues(alpha: 0.84),
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          if (showCards && displayed.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final r in displayed) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: cBlue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cBlue.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.alt_route,
                        size: 18,
                        color: cDarkBlue.withValues(alpha: 0.80),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.roadName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: cDarkBlue.withValues(alpha: 0.90),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.metersAway.toStringAsFixed(0)} m away'
                            '${r.roadType.trim().isEmpty ? '' : ' • ${r.roadType}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: cDarkBlue.withValues(alpha: 0.72),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _riskBadgeBackgroundColor(
                          _riskFromMaxRiskLevel(r.riskLevel),
                          cSafe,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _riskBadgeTextFromRiskLevelInt(r.riskLevel),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: cDarkBlue.withValues(alpha: 0.84),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (remaining > 0)
              Text(
                '+$remaining more',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: cDarkBlue.withValues(alpha: 0.70),
                ),
              ),
          ],
          if (showCards && roads.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No flooded roads within 200 m',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cDarkBlue.withValues(alpha: 0.70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatUpdatedAt(DateTime dt) {
    dt = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    const cPrimary = Color(0xFF13005A);
    const cDarkBlue = Color(0xFF00337C);
    const cBlue = Color(0xFF1C82AD);
    const cAccent = Color(0xFF03C988);
    const cSafe = Color(0xFF2ECC71);

    final riskLevel = _floodLoading || _floodError
        ? null
        : _riskFromMaxRiskLevel(_maxRiskLevel);

    final trimmedAddress = (widget.address ?? '').trim();
    final hasAddress = trimmedAddress.isNotEmpty;

    final expandedDetails = AnimatedCrossFade(
      crossFadeState: _expanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 180),
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.update,
                  size: 18,
                  color: cDarkBlue.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last updated at ${_formatUpdatedAt(_floodLastUpdatedAt ?? _placeholderUpdatedAt)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cDarkBlue.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 18,
                  color: cDarkBlue.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _placeholderRainForecast,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cDarkBlue.withValues(alpha: 0.80),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final riskLine = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 18,
          color: cDarkBlue.withValues(alpha: 0.70),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _riskText(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cDarkBlue.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0) {
          _setExpanded(true);
        } else if (v > 0) {
          _setExpanded(false);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.place, color: cPrimary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name.trim().isEmpty
                        ? 'Selected location'
                        : widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  child: AnimatedBuilder(
                    animation: _riskPulse,
                    builder: (context, _) {
                      final color = (_floodLoading || _floodError)
                          ? Colors.grey.withValues(alpha: 0.55)
                          : _riskDotColor(
                              safe: cSafe,
                              level: riskLevel ?? _FloodRiskLevel.safe,
                            );
                      final glowScale = 1.0 + (_riskPulse.value * 1.2);
                      final glowOpacity = 0.35 * (1.0 - _riskPulse.value);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: glowScale,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: glowOpacity),
                              ),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.close,
                      color: cDarkBlue.withValues(alpha: 0.70),
                    ),
                  ),
                ),
              ],
            ),
            if (hasAddress) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: cDarkBlue.withValues(alpha: 0.70),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trimmedAddress,
                      maxLines: _expanded ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cDarkBlue.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.directions,
                  size: 18,
                  color: cDarkBlue.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FutureBuilder<int?>(
                    future: _distanceMetersFuture,
                    builder: (context, snap) {
                      String text;
                      if (snap.connectionState == ConnectionState.waiting) {
                        text = 'Calculating distance…';
                      } else {
                        final meters = snap.data;
                        if (meters == null) {
                          text = 'Distance unavailable';
                        } else if (meters >= 1000) {
                          text =
                              '${(meters / 1000).toStringAsFixed(1)} km away';
                        } else {
                          text = '$meters m away';
                        }
                      }

                      return Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cDarkBlue.withValues(alpha: 0.82),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            riskLine,
            _buildFloodedRoadsSection(
              cDarkBlue: cDarkBlue,
              cBlue: cBlue,
              cSafe: cSafe,
            ),
            expandedDetails,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onNavigate,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onSave,
                    icon: const Icon(Icons.bookmark_border),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cDarkBlue,
                      side: BorderSide(
                        color: cDarkBlue.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
