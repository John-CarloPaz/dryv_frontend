import 'package:flutter/material.dart';

/// Full-screen loading overlay.
///
/// UX requirement: animated full-screen UI with text "Calculating for Safest Route".
class SafestRouteLoadingOverlay extends StatefulWidget {
  final String message;

  const SafestRouteLoadingOverlay({
    super.key,
    this.message = 'Calculating for Safest Route',
  });

  @override
  State<SafestRouteLoadingOverlay> createState() =>
      _SafestRouteLoadingOverlayState();
}

class _SafestRouteLoadingOverlayState extends State<SafestRouteLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final scale = 0.92 + (t * 0.08);
                    return Transform.scale(
                      scale: scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        color: scheme.primary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
