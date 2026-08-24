import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the hero sits in the first-run sequence.
///
/// `OnboardingScreen` drives four steps from its own state rather than from
/// `OnboardingPages`: welcome (the one `PageView` page), the evidence-method
/// explainer, the remote-processing consent step, and then this hero. The hero
/// is last, and its CTA is the only thing wired to `_complete()`, which is the
/// only place `context.go('/record')` is called — so reaching the record
/// surface is not possible without passing through it.
///
/// The consent decision itself writes through `AppServices.instance`, which is
/// not available in a widget test, so these tests drive the flow as far as the
/// consent step and assert the hero is not reachable before it.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('on-device hero placement', () {
    testWidgets('is not shown on the welcome step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
      expect(find.byKey(OnDeviceHeroScreen.continueKey), findsNothing);
    });

    testWidgets('is not shown on the evidence-method step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('evidence_method_onboarding_continue')),
        findsOneWidget,
      );
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
    });

    testWidgets('is not shown until the consent decision is answered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester);
      await tester.tap(
        find.byKey(const Key('evidence_method_onboarding_continue')),
      );
      await _pumpFrames(tester);

      // The consent step is on screen and still un-answered.
      expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
      expect(
        find.byKey(const Key('remote_processing_consent_allow')),
        findsOneWidget,
      );
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
    });
  });
}
