import 'package:archiveme_mobile/features/onboarding/ui/evidence_method_onboarding_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repo_file_scan.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _advanceToConsent(WidgetTester tester) async {
  await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
  await _pumpFrames(tester);
}

void main() {
  group('V1 onboarding — two-screen first-run', () {
    test('welcome page is the only OnboardingPages entry', () {
      expect(OnboardingPages.pageCount, 1);
      expect(
        OnboardingPages.pages.single.title,
        ConsumerUiCopy.onboardingPositioningHeadline,
      );
      expect(
        OnboardingPages.pages.single.body,
        ConsumerUiCopy.onboardingPositioningBody,
      );
    });

    test('record does not re-ask the first-run send choice', () {
      final captureCopy = [
        MicrophonePermissionCopy.neededTitle,
        MicrophonePermissionCopy.neededBody,
        MicrophonePermissionCopy.requestMicrophoneCta,
      ].join('\n');
      expect(
        captureCopy,
        isNot(contains(RemoteProcessingConsentCopy.allowCta)),
      );
      expect(
        captureCopy,
        isNot(contains(RemoteProcessingConsentCopy.declineCta)),
      );
      expect(captureCopy, isNot(contains(RemoteProcessingConsentCopy.title)));

      for (final relative in const [
        'lib/features/capture_flow/ui/capture_flow_panels.dart',
        'lib/features/capture_flow/ui/capture_screen.dart',
      ]) {
        final source = resolveRepoScanFile(relative).readAsStringSync();
        expect(
          source.contains('RemoteProcessingConsent'),
          isFalse,
          reason: relative,
        );
        expect(source.contains(RemoteProcessingConsentCopy.allowCta), isFalse);
      }
    });

    test('copy avoids diagnostic, therapeutic, and aspirational promises', () {
      expect(
        ConsumerUiCopy.onboardingPositioningHeadline,
        OnboardingV1Copy.welcomeTitle,
      );
      expect(
        ConsumerUiCopy.onboardingPositioningBody.toLowerCase(),
        contains('does not diagnose'),
      );
      expect(
        ConsumerUiCopy.onboardingPositioningBody.toLowerCase(),
        isNot(contains('cited')),
      );
      expect(
        EvidenceMethodOnboardingCopy.title.toLowerCase(),
        isNot(contains('finds patterns')),
      );
      expect(
        EvidenceMethodOnboardingCopy.body.toLowerCase(),
        isNot(contains('confidence band')),
      );
    });

    testWidgets('screen 1 shows the evidence sentence, two dots, Continue', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await _pumpFrames(tester);

      expect(find.text('ArchiveMe'), findsOneWidget);
      expect(
        find.text(ConsumerUiCopy.onboardingPositioningHeadline),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.onboardingPositioningBody),
        findsOneWidget,
      );
      expect(find.text(OnboardingV1Copy.pillar2Title), findsNothing);
      expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Start my archive'), findsNothing);
      expect(
        find.byKey(const Key('onboarding_progress_dot_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('onboarding_progress_dot_1')),
        findsOneWidget,
      );
    });

    testWidgets('screen 2 is a short send choice with equal-weight buttons', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await _pumpFrames(tester);

      await _advanceToConsent(tester);

      expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.body), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.lede), findsNothing);
      expect(
        find.text(RemoteProcessingConsentCopy.changeLaterFootnote),
        findsOneWidget,
      );
      expect(find.byKey(OnDeviceArchitectureSection.sectionKey), findsNothing);
      expect(
        find.text(OnDeviceArchitectureCopy.architectureBody),
        findsNothing,
      );
      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
      expect(find.text(RemoteProcessingConsentCopy.allowCta), findsOneWidget);
      expect(find.text(RemoteProcessingConsentCopy.declineCta), findsOneWidget);
      expect(
        find.text(RemoteProcessingConsentCopy.moreDetailLink),
        findsNothing,
      );
      expect(
        find.byKey(const Key('remote_processing_consent_allow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('remote_processing_consent_decline')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onboarding_progress_dots')), findsOneWidget);

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
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
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
            child: const MaterialApp(home: OnboardingScreen()),
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
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await _pumpFrames(tester);

      await _advanceToConsent(tester);

      expect(
        tester.getSemantics(find.text(RemoteProcessingConsentCopy.title)),
        matchesSemantics(isHeader: true),
      );
    });
  });
}
