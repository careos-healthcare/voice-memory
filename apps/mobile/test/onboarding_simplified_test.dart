import 'package:archiveme_mobile/features/onboarding/ui/evidence_method_onboarding_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _advanceToConsent(WidgetTester tester) async {
  await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
  await _pumpFrames(tester);
  await tester.tap(find.byKey(const Key('evidence_method_onboarding_continue')));
  await _pumpFrames(tester);
}

void main() {
  group('V1 onboarding — trust pillars and consent', () {
    test('welcome page is the only OnboardingPages entry', () {
      expect(OnboardingPages.pageCount, 1);
      expect(OnboardingPages.pages.single.title,
          ConsumerUiCopy.onboardingPositioningHeadline);
      expect(OnboardingPages.pages.single.body,
          ConsumerUiCopy.onboardingPositioningBody);
    });

    test('copy avoids diagnostic, therapeutic, and aspirational promises', () {
      expect(ConsumerUiCopy.onboardingPositioningHeadline,
          OnboardingV1Copy.welcomeTitle);
      expect(ConsumerUiCopy.onboardingPositioningBody, contains('evidence-backed'));
      expect(ConsumerUiCopy.onboardingPositioningBody.toLowerCase(),
          contains('does not diagnose'));
      expect(EvidenceMethodOnboardingCopy.title.toLowerCase(),
          isNot(contains('finds patterns')));
      expect(EvidenceMethodOnboardingCopy.body.toLowerCase(),
          isNot(contains('confidence band')));
    });

    testWidgets('screen 1 shows contract copy, pillars, and Continue', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      expect(find.text('ArchiveMe'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.onboardingPositioningHeadline),
          findsOneWidget);
      expect(find.text(ConsumerUiCopy.onboardingPositioningBody), findsOneWidget);
      expect(find.text(OnboardingV1Copy.pillar2Title), findsOneWidget);
      expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Start my archive'), findsNothing);
    });

    testWidgets('screen 3 is remote consent with equal-weight choices', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      await _advanceToConsent(tester);

      expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
      expect(
          find.byKey(OnDeviceArchitectureSection.sectionKey), findsOneWidget);
      expect(
          find.text(OnDeviceArchitectureCopy.architectureBody), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.allowCta), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.declineCta), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.moreDetailLink), findsOneWidget);
      expect(find.byKey(const Key('remote_processing_consent_allow')),
          findsOneWidget);
      expect(find.byKey(const Key('remote_processing_consent_decline')),
          findsOneWidget);

      final allow = tester.widget<OutlinedButton>(
        find.byKey(const Key('remote_processing_consent_allow')),
      );
      final decline = tester.widget<OutlinedButton>(
        find.byKey(const Key('remote_processing_consent_decline')),
      );
      expect(allow.style?.minimumSize, decline.style?.minimumSize);
    });

    testWidgets('does not request microphone during onboarding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      expect(find.textContaining('microphone'), findsNothing);
      expect(find.textContaining('Use voice to record'), findsNothing);

      await _advanceToConsent(tester);

      expect(find.textContaining('microphone'), findsNothing);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const MaterialApp(
              home: OnboardingScreen(debugStartAtWelcome: true),
            ),
          ),
        );
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);

        await _advanceToConsent(tester);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('consent step exposes semantics for screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      await _pumpFrames(tester);

      await _advanceToConsent(tester);

      expect(
        tester.getSemantics(find.text(RemoteProcessingConsentCopy.title)),
        matchesSemantics(isHeader: true),
      );
    });
  });
}
