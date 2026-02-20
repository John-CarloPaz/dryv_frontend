import 'package:flutter/material.dart';

import 'package:dryvmobapp/Screens/Authentication/auth_gate.dart';
import 'package:dryvmobapp/Screens/Intro/app_intro_screen.dart';
import 'package:dryvmobapp/Services/intro_preferences.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class IntroGate extends StatelessWidget {
  final Widget seenChild;
  final Widget unseenChild;

  const IntroGate({
    super.key,
    this.seenChild = const AuthGate(),
    this.unseenChild = const AppIntroScreen(),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: IntroPreferences.getSeen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final seen = snapshot.data ?? false;
        return seen ? seenChild : unseenChild;
      },
    );
  }
}
