import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';

void main() {
  testWidgets('launch onboarding four-step prove story', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.onboardingPositioningBody), findsOneWidget);

    for (var i = 1; i < OnboardingPages.pageCount; i++) {
      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await tester.pumpAndSettle();
      expect(find.text(OnboardingPages.pages[i].title), findsOneWidget);
    }

    expect(find.text(ConsumerUiCopy.onboardingFinalCta), findsOneWidget);
    expect(find.text('I want freedom'), findsNothing);
  });

  testWidgets('onboarding final CTA visible on small phone surface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    for (var i = 0; i < OnboardingPages.pageCount - 1; i++) {
      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await tester.pumpAndSettle();
    }

    expect(find.text(ConsumerUiCopy.onboardingFinalCta), findsOneWidget);
  });

  testWidgets('onboarding does not overflow on iPad-width surface', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ArchiveMe'), findsOneWidget);
  });
}
