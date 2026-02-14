import 'package:flutter/material.dart';

class RouteInfoSheet extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final distanceText = distanceMeters == null
        ? null
        : _formatDistance(distanceMeters!);
    final etaText = durationSeconds == null
        ? null
        : _formatEta(durationSeconds!);

    final summaryBits = <String>[];
    if (distanceText != null) summaryBits.add(distanceText);
    if (etaText != null) summaryBits.add(etaText);

    final summary = summaryBits.isEmpty ? null : summaryBits.join(' • ');

    final riskText = maxRiskLevel == null
        ? null
        : 'Max risk level: $maxRiskLevel';

    return DraggableScrollableSheet(
      initialChildSize: 0.26,
      minChildSize: 0.18,
      maxChildSize: 0.55,
      builder: (context, scrollController) {
        return Material(
          elevation: 12,
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                destinationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
              if (riskText != null) ...[
                const SizedBox(height: 4),
                Text(
                  riskText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartDriving,
                  child: const Text('Start Driving'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onExit,
                  child: const Text('Exit'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
