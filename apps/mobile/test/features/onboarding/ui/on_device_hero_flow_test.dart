import 'package:archiveme_mobile/features/onboarding/privacy_onboarding_flow.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

/// The confirmation hero is not part of first-run. Privacy onboarding
/// walks from the on-device explanation to the permission step.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  OnboardingPermissionClient permissions() {
    return OnboardingPermissionClient(
      status: (_) async => PermissionStatus.denied,
      request: (_) async => PermissionStatus.granted,
      openSettings: () async => true,
    );
  }

  group('on-device hero placement', () {
    testWidgets('is not shown on the privacy step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacyOnboardingFlow(
            permissions: permissions(),
            preparePurchases: () async {},
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Your words stay on this device'), findsOneWidget);
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
      expect(find.byKey(OnDeviceHeroScreen.continueKey), findsNothing);
    });

    testWidgets('is not shown on the permission step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacyOnboardingFlow(
            permissions: permissions(),
            preparePurchases: () async {},
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Microphone and storage'), findsOneWidget);
      expect(
        find.textContaining('The system prompt appears after you continue.'),
        findsOneWidget,
      );
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
    });
  });
}
