import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Route-level loading overlay.
///
/// Intended to be pushed as a non-opaque route so the underlying map remains
/// visible. Displays a Lottie animation with text "Calculating Safest Route".
class SafestRouteLoadingOverlay extends StatelessWidget {
  final String message;

  /// Lottie JSON asset to render.
  final String lottieAssetPath;

  const SafestRouteLoadingOverlay({
    super.key,
    this.message = 'Calculating Safest Route',
    this.lottieAssetPath = 'lib/assets/images/Compass.json',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: scheme.surface.withValues(alpha: 0.62),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    minWidth: 260,
                  ),
                  child: Material(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxWidth.clamp(220, 420);
                          final lottieSize = (size * 0.38).clamp(96, 168);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: lottieSize.toDouble(),
                                height: lottieSize.toDouble(),
                                child: Lottie.asset(
                                  lottieAssetPath,
                                  fit: BoxFit.contain,
                                  frameRate: FrameRate.max,
                                  repeat: true,
                                  animate: true,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 4,
                                        color: scheme.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
