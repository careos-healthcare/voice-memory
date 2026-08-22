import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('focused beta onboarding has welcome page only in OnboardingPages', () {
    expect(OnboardingPages.pageCount, 1);
    expect(OnboardingPages.pages, hasLength(1));
  });

  test('welcome page uses V1 product contract copy', () {
    final page = OnboardingPages.pages[0];
    expect(page.title, ConsumerUiCopy.onboardingPositioningHeadline);
    expect(page.body, ConsumerUiCopy.onboardingPositioningBody);
    expect(page.title, OnboardingV1Copy.welcomeTitle);
    expect(page.body, contains('evidence-backed'));
    expect(page.body.toLowerCase(), contains('does not diagnose'));
    expect(page.stepNumber, isNull);
  });

  test('trust pillars state four explicit commitments', () {
    expect(OnboardingV1Copy.trustPillars, hasLength(4));
    expect(OnboardingV1Copy.pillar1Title, contains('cited'));
    expect(OnboardingV1Copy.pillar2Title.toLowerCase(), contains('by default'));
    expect(OnboardingV1Copy.pillar3Title.toLowerCase(), contains('storage'));
    expect(OnboardingV1Copy.pillar4Title.toLowerCase(), contains('control'));

    for (final pillar in OnboardingV1Copy.trustPillars) {
      expect(pillar.title.trim(), isNotEmpty);
      expect(pillar.body.trim(), isNotEmpty);
      expect(pillar.body.toLowerCase(), isNot(contains('therapy')));
      expect(pillar.body.toLowerCase(), isNot(contains('diagnosis')));
    }
  });

  // Remote processing exists and is consent-gated (`/api/transcribe`, sync),
  // and storage protection is a runtime flag with an "unavailable" state, so
  // these pillars must not claim processing is exclusively local or that the
  // archive is encrypted. See on_device_architecture_copy.dart.
  test('trust pillars make no unqualified locality or encryption claim', () {
    for (final pillar in OnboardingV1Copy.trustPillars) {
      final text = '${pillar.title} ${pillar.body}'.toLowerCase();
      expect(text, isNot(contains('entirely')));
      expect(text, isNot(contains('encrypt')));
      expect(text, isNot(contains('sqlite')));
    }
    expect(
      OnboardingV1Copy.pillar2Body,
      contains(PrivacyCopyPolicy.nothingSentUnlessFeatureChosen),
    );
  });
}
