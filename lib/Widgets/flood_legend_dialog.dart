import 'package:flutter/material.dart';

enum FloodLegendMode { floodMap, realtimeFlood }

class FloodLegendDialog extends StatelessWidget {
  final FloodLegendMode mode;
  final VoidCallback onClose;
  final DateTime? lastUpdatedAt;
  final String? lastUpdatedAtText;

  const FloodLegendDialog({
    super.key,
    required this.mode,
    required this.onClose,
    this.lastUpdatedAt,
    this.lastUpdatedAtText,
  });

  String _formatUpdatedAt(DateTime dt) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthName = months[(dt.month - 1).clamp(0, 11)];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';

    return '$monthName ${dt.day}, ${dt.year} • $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    const cPrimary = Color(0xFF13005A);
    const cDarkBlue = Color(0xFF00337C);

    final isFloodMap = mode == FloodLegendMode.floodMap;
    final titleText = isFloodMap
        ? 'Flood Risk Levels'
        : 'Realtime Flood Passability';

    // Placeholder for now (backend will wire this later).
    final updatedAt =
        lastUpdatedAt ?? DateTime.now().subtract(const Duration(minutes: 17));
    final updatedAtText = lastUpdatedAtText ?? _formatUpdatedAt(updatedAt);

    Widget legendRow({
      required Color color,
      required String title,
      required String subtitle,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: cDarkBlue.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 112, 14, 0),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Material(
                color: Colors.white,
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: cPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              titleText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: cPrimary,
                              ),
                            ),
                          ),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onClose,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: cDarkBlue.withValues(alpha: 0.70),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isFloodMap) ...[
                        legendRow(
                          color: const Color(0xFFE74C3C),
                          title: 'Red — Flood Risk Level 3 (High)',
                          subtitle: 'High flood risk area.',
                        ),
                        const SizedBox(height: 10),
                        legendRow(
                          color: const Color(0xFFFF8C00),
                          title: 'Orange — Flood Risk Level 2 (Moderate)',
                          subtitle: 'Moderate flood risk area.',
                        ),
                        const SizedBox(height: 10),
                        legendRow(
                          color: const Color(0xFFF1C40F),
                          title: 'Yellow — Flood Risk Level 1 (Low)',
                          subtitle: 'Low flood risk area.',
                        ),
                      ] else ...[
                        legendRow(
                          color: const Color(0xFFE74C3C),
                          title: 'Red — Not passable (all vehicle types)',
                          subtitle: 'Waist level to chest level flooding.',
                        ),
                        const SizedBox(height: 10),
                        legendRow(
                          color: const Color(0xFFFF8C00),
                          title: 'Orange — Not passable (light vehicles)',
                          subtitle: 'Half tire to knee level flooding.',
                        ),
                        const SizedBox(height: 10),
                        legendRow(
                          color: const Color(0xFF2ECC71),
                          title: 'Green — Passable (all vehicle types)',
                          subtitle: 'Gutter level to half knee level flooding.',
                        ),
                      ],
                      const SizedBox(height: 2),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: cDarkBlue.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.update,
                            size: 16,
                            color: cDarkBlue.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Map Layer Last Updated At: $updatedAtText',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cDarkBlue.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap anywhere on the map to close.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cDarkBlue.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
