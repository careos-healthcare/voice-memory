import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('welcome screen uses mind-map positioning copy', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(
      find.text('Build a private mind map of what keeps repeating'),
      findsOneWidget,
    );
    expect(find.textContaining('Save real moments'), findsOneWidget);
    expect(
      find.textContaining('ArchiveMe connects them into patterns'),
      findsOneWidget,
    );
    expect(find.text('Notice the pressure loops that keep repeating'), findsNothing);
    expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
  });

  testWidgets('launch onboarding shows promise and three loop steps', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.onboardingPositioningBody), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    for (var i = 1; i < OnboardingPages.pageCount; i++) {
      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester, frames: 5);
      expect(find.text(OnboardingPages.pages[i].title), findsOneWidget);
      expect(find.text(OnboardingPages.pages[i].body), findsOneWidget);
    }

    expect(find.text(ConsumerUiCopy.onboardingFinalCta), findsOneWidget);
    expect(find.text('I want freedom'), findsNothing);
    expect(find.text('What you kept doing'), findsNothing);
  });

  testWidgets('onboarding final CTA visible on small phone surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester, frames: 5);

    for (var i = 0; i < OnboardingPages.pageCount - 1; i++) {
      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester, frames: 5);
    }

    expect(find.text(ConsumerUiCopy.onboardingFinalCta), findsOneWidget);
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
