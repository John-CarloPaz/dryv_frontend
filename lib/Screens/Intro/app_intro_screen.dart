import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dryvmobapp/Services/intro_preferences.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _IntroSlideData {
  final String imageAssetPath;
  final String title;
  final String subtitle;

  const _IntroSlideData({
    required this.imageAssetPath,
    required this.title,
    required this.subtitle,
  });
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = <_IntroSlideData>[
    _IntroSlideData(
      imageAssetPath: 'lib/assets/images/intro1.png',
      title: 'Avoid Flooded Roads',
      subtitle:
          'Real-time alerts help you steer clear\nof flood-prone streets.',
    ),
    _IntroSlideData(
      imageAssetPath: 'lib/assets/images/intro2.png',
      title: 'Smart Route Rerouting',
      subtitle: 'We automatically guide you to safer,\npassable roads.',
    ),
    _IntroSlideData(
      imageAssetPath: 'lib/assets/images/intro3.png',
      title: 'Get There Safely',
      subtitle: 'Travel with confidence, even during\nheavy rain.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < _slides.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }

    await IntroPreferences.setSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'lib/assets/images/header-icon.svg',
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final imageMaxHeight = constraints.maxHeight * 0.56;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: imageMaxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Image.asset(
                                  slide.imageAssetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                color: AppColors.darkBlue.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              _SlideIndicator(count: _slides.length, index: _index),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _index == _slides.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _SlideIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.darkBlue.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}
