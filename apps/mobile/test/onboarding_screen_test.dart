import 'package:archiveme_mobile/features/onboarding/ui/evidence_method_onboarding_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_trust_pillars_section.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repo_file_scan.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('first-run source is three screens: evidence, trust, send choice', () {
    final source = resolveRepoScanFile(
      'lib/screens/onboarding_screen.dart',
    ).readAsStringSync();
    expect(source.contains('OnDeviceHeroScreen'), isFalse);
    expect(source.contains('EvidenceMethodOnboardingScreen'), isFalse);
    expect(source.contains('_conceptualStepCount = 3'), isTrue);
    expect(source.contains('OnboardingTrustPillarsSection'), isTrue);
    expect(source.contains('OnboardingRemoteProcessingDecision.record'), isTrue);
    expect(source.contains("context.go('/record')"), isTrue);
  });

  testWidgets('welcome screen is the evidence sentence, not four pillars', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text(OnboardingV1Copy.welcomeTitle), findsOneWidget);
    expect(find.text(OnboardingV1Copy.welcomeBody), findsOneWidget);
    expect(find.byKey(OnboardingTrustPillarsSection.sectionKey), findsNothing);
    expect(find.text(OnboardingV1Copy.pillar1Title), findsNothing);
    expect(find.text(OnboardingV1Copy.pillar4Title), findsNothing);
    expect(find.textContaining('evidence-backed'), findsNothing);
    expect(find.textContaining('Not a diary'), findsNothing);
    expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
    expect(find.byKey(const Key('onboarding_progress_dots')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_progress_dot_0')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_progress_dot_1')), findsOneWidget);
  });

  testWidgets('continue opens the trust pillars, then the send choice', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.onboardingPositioningBody), findsOneWidget);

    await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
    await _pumpFrames(tester);

    expect(
      find.byKey(OnboardingTrustPillarsSection.sectionKey),
      findsOneWidget,
    );
    expect(find.text(OnboardingV1Copy.pillar1Title), findsOneWidget);
    expect(find.text(OnboardingV1Copy.pillar4Title), findsOneWidget);
    expect(find.text(RemoteProcessingConsentCopy.title), findsNothing);

    await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
    await _pumpFrames(tester);

    expect(find.text(EvidenceMethodOnboardingCopy.title), findsNothing);
    expect(find.byKey(OnDeviceHeroScreen.screenKey), findsNothing);
    expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
    expect(find.text(RemoteProcessingConsentCopy.body), findsOneWidget);
    expect(find.byKey(OnDeviceArchitectureSection.sectionKey), findsNothing);
    expect(
      find.text(RemoteProcessingConsentCopy.moreDetailLink),
      findsNothing,
    );
    expect(
      find.byKey(const Key('remote_processing_consent_allow')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding_progress_dots')), findsOneWidget);
  });

  testWidgets('onboarding CTA visible on small phone surface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
  });

  testWidgets('onboarding does not overflow on iPad-width surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
