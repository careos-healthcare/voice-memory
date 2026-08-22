import 'package:archiveme_mobile/features/onboarding/ui/onboarding_trust_pillars_section.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
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
  testWidgets('welcome screen uses V1 contract copy and trust pillars', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text(OnboardingV1Copy.welcomeTitle), findsOneWidget);
    expect(find.textContaining('evidence-backed'), findsOneWidget);
    expect(find.text(TrustBadgeCopy.onDeviceProcessing), findsOneWidget);
    expect(find.byKey(OnboardingTrustPillarsSection.sectionKey), findsOneWidget);
    expect(find.text(OnboardingV1Copy.pillar1Title), findsOneWidget);
    expect(find.text(OnboardingV1Copy.pillar4Title), findsOneWidget);
    expect(find.textContaining('Not a diary'), findsNothing);
    expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
  });

  testWidgets('welcome screen states each trust pillar exactly once', (
    tester,
  ) async {
    // `TrustBadge` and `OnboardingTrustPillarsSection` both rendered here, and
    // `TrustBadgeCopy.onDeviceProcessing` / `.storage` are the titles of
    // pillars 2 and 3, so the screen said each of those twice. Titles are
    // aliased now, which means a duplicate render shows up here as two matches
    // rather than as two constants that quietly drifted into agreement.
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    for (final pillar in OnboardingV1Copy.trustPillars) {
      expect(
        find.text(pillar.title),
        findsOneWidget,
        reason: 'pillar title rendered more than once: ${pillar.title}',
      );
    }
    expect(find.text(TrustBadgeCopy.storage), findsOneWidget);
  });

  testWidgets('continue advances through evidence step to consent screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.onboardingPositioningBody), findsOneWidget);

    await _advanceToConsent(tester);

    expect(find.text(RemoteProcessingConsentCopy.title), findsOneWidget);
    expect(
        find.byKey(OnDeviceArchitectureSection.sectionKey), findsOneWidget);
    expect(find.byKey(const Key('remote_processing_consent_allow')),
        findsOneWidget);
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
