import 'package:flutter/material.dart';

class RouteInfoSheet extends StatefulWidget {
  final String destinationName;
  final double? distanceMeters;
  final double? durationSeconds;
  final int? maxRiskLevel;
  final VoidCallback onStartDriving;
  final VoidCallback onExit;

  const RouteInfoSheet({
    super.key,
    required this.destinationName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maxRiskLevel,
    required this.onStartDriving,
    required this.onExit,
  });

  @override
  State<RouteInfoSheet> createState() => _RouteInfoSheetState();
}

class _RouteInfoSheetState extends State<RouteInfoSheet>
    with TickerProviderStateMixin {
  static const _cPrimary = Color(0xFF13005A);
  static const _cDarkBlue = Color(0xFF00337C);
  static const _cBlue = Color(0xFF1C82AD);
  static const _cAccent = Color(0xFF03C988);

  late final AnimationController _riskPulseController;
  late final Animation<double> _riskPulse;

  @override
  void initState() {
    super.initState();
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

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatEta(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  Color _riskDotColor(int? maxRiskLevel) {
    final r = maxRiskLevel;
    if (r == null) return _cBlue.withValues(alpha: 0.70);
    if (r <= 0) return _cAccent;
    if (r == 1) return _cBlue;
    if (r == 2) return _cDarkBlue;
    return _cPrimary;
  }

  String _riskTitle(int? maxRiskLevel) {
    final r = maxRiskLevel;
    if (r == null) return 'Risk level unavailable';
    return 'Risk level: $r';
  }

  String? _riskMessage(int? maxRiskLevel) {
    final r = maxRiskLevel;
    if (r == null) return null;

    // Requested: if maxRiskLevel == 1, show this exact message.
    if (r == 1) {
      return 'Expect flooded road in gutter level to below the knee level';
    }

    // Best-effort alignment with the app’s “Realtime Flood Passability” legend.
    if (r == 2) return 'Half tire to knee level flooding.';
    if (r >= 3) return 'Waist level to chest level flooding.';
    if (r <= 0) return 'Road is passable.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = widget.distanceMeters == null
      ? null
      : _formatDistance(widget.distanceMeters!);
    final etaText = widget.durationSeconds == null
      ? null
      : _formatEta(widget.durationSeconds!);

    final summaryBits = <String>[];
    if (distanceText != null) summaryBits.add(distanceText);
    if (etaText != null) summaryBits.add(etaText);

    final driveValue = () {
      if (etaText == null && distanceText == null) return '—';
      if (etaText != null && distanceText != null) {
        return '$etaText • $distanceText';
      }
      return etaText ?? distanceText ?? '—';
    }();

    final riskTitle = _riskTitle(widget.maxRiskLevel);
    final riskMessage = _riskMessage(widget.maxRiskLevel);
    final riskDot = _riskDotColor(widget.maxRiskLevel);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 14,
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _cAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.place,
                      color: _cPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _cPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: AnimatedBuilder(
                      animation: _riskPulse,
                      builder: (context, _) {
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
                                  color: riskDot.withValues(alpha: glowOpacity),
                                ),
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: riskDot,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.directions_car_filled_outlined,
                title: 'Drive',
                value: driveValue,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.shield_outlined,
                title: 'Risk',
                value: riskTitle,
                subtitle: riskMessage,
              ),
              const SizedBox(height: 12),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onStartDriving,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'START',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _cDarkBlue,
                          side: BorderSide(
                            color: _cDarkBlue.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'EXIT',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const cDarkBlue = Color(0xFF00337C);
    const cPrimary = Color(0xFF13005A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cDarkBlue.withValues(alpha: 0.72)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cDarkBlue.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cPrimary,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cDarkBlue.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
