import 'package:dryvmobapp/Models/lat_lng.dart';
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
  bool _expanded = false;
  Future<int?>? _distanceMetersFuture;

  late final AnimationController _riskPulseController;
  late final Animation<double> _riskPulse;

  // Placeholders for now (to be replaced with backend data later).
  final _FloodRiskLevel _placeholderRisk = _FloodRiskLevel.moderate;
  final DateTime _placeholderUpdatedAt = DateTime.now().subtract(
    const Duration(minutes: 17),
  );
  final String _placeholderRainForecast = 'Moderate Rainfall in 3 Hours';

  @override
  void initState() {
    super.initState();
    _distanceMetersFuture = _computeDistanceMeters();

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

  Color _riskDotColor(Color safe) {
    switch (_placeholderRisk) {
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
    switch (_placeholderRisk) {
      case _FloodRiskLevel.safe:
        return 'Location is flood safe';
      case _FloodRiskLevel.low:
        return 'Flood risk within 150m: Low';
      case _FloodRiskLevel.moderate:
        return 'Flood risk within 150m: Moderate';
      case _FloodRiskLevel.high:
        return 'Flood risk within 150m: High';
    }
  }

  String _formatUpdatedAt(DateTime dt) {
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
            ),
            const SizedBox(height: 8),
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
                    'Last updated at ${_formatUpdatedAt(_placeholderUpdatedAt)}',
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
                      final color = _riskDotColor(cSafe);
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
