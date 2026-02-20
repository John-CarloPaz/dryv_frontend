// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:dryvmobapp/Screens/Intro/app_intro_screen.dart';
import 'package:dryvmobapp/Screens/Intro/intro_gate.dart';

void main() {
  testWidgets('IntroGate shows intro when not seen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: IntroGate(
          seenChild: Text('seen'),
          unseenChild: Text('unseen'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('unseen'), findsOneWidget);
    expect(find.text('seen'), findsNothing);
  });

  testWidgets('IntroGate skips intro when already seen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'intro_seen_v1': true});

    await tester.pumpWidget(
      const MaterialApp(
        home: IntroGate(
          seenChild: Text('seen'),
          unseenChild: Text('unseen'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('seen'), findsOneWidget);
    expect(find.text('unseen'), findsNothing);
  });

  testWidgets('App intro navigates to login on Get Started', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/auth/login': (_) => const Scaffold(body: Text('login')),
        },
        home: const AppIntroScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avoid Flooded Roads'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Smart Route Rerouting'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Get There Safely'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });
}
