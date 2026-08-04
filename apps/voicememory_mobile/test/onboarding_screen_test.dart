import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('welcome screen leads with the V1 promise', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(find.text(OnboardingPages.pages.first.title), findsOneWidget);
    // Asserted through the constant rather than a fragment of its wording, so
    // this stays a test of what the screen renders. The wording itself is
    // owned by the positioning copy guards.
    expect(find.text(OnboardingPages.pages.first.body), findsOneWidget);
    expect(find.text('Record a moment'), findsOneWidget);
    expect(find.text('Type instead'), findsOneWidget);
  });

  testWidgets('launch onboarding is one promise before the real capture flow', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    expect(find.text(OnboardingPages.pages.first.body), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(OnboardingPages.pageCount, 1);
    expect(find.text('Record a moment'), findsOneWidget);
    expect(find.text('Type instead'), findsOneWidget);
    expect(find.textContaining('Who are 2 key people'), findsNothing);
  });

  testWidgets('onboarding final CTA visible on small phone surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(find.text('Record a moment'), findsOneWidget);
    expect(find.text('Type instead'), findsOneWidget);
  });

  testWidgets('onboarding does not overflow on iPad-width surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(find.text('ArchiveMe'), findsOneWidget);
  });
}
