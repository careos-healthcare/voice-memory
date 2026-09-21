import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The confirmation hero is not part of first-run. Screen 2's buttons
/// persist the send answer and open Record.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('on-device hero placement', () {
    testWidgets('is not shown on the evidence step', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await _pumpFrames(tester);

      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
      expect(find.byKey(OnDeviceHeroScreen.continueKey), findsNothing);
    });

    testWidgets('is not shown on the send-choice step', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await _pumpFrames(tester);

      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester);

      expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
      expect(
        find.byKey(const Key('remote_processing_consent_allow')),
        findsOneWidget,
      );
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
    });
  });
}
