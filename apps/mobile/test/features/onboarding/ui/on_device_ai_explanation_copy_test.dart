import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact sentence the product brief asked to ship. It is false here:
/// remote transcription, analysis, Firebase Analytics, and a production
/// backend all exist. This list is the phrase-exact record of that request.
const _requestedFalseAbsolute =
    'Your data stays on your phone. Our AI runs entirely on your device, '
    'meaning your personal information never goes to the cloud.';

const _requestedFalseOnDeviceBody =
    'Our AI processes everything directly on this device. Your data never '
    'leaves your phone.';

String get _fullExplanationText => [
  OnDeviceAiExplanationCopy.heading,
  OnDeviceAiExplanationCopy.title,
  OnDeviceAiExplanationCopy.lede,
  OnDeviceAiExplanationCopy.body,
  ...OnDeviceAiExplanationCopy.bullets,
  OnDeviceAiExplanationCopy.continueCta,
  OnDeviceAiExplanationCopy.understandCta,
  OnDeviceAiExplanationCopy.cancelCta,
].join(' ');

void main() {
  group('OnDeviceAiExplanationCopy', () {
    test('aliases the live hero and architecture statements', () {
      expect(OnDeviceAiExplanationCopy.title, OnDeviceHeroCopy.title);
      expect(OnDeviceAiExplanationCopy.lede, OnDeviceHeroCopy.lede);
      expect(
        OnDeviceAiExplanationCopy.journalDefault,
        PrivacyClaimCatalogue.momentsStayLocal,
      );
      expect(
        OnDeviceAiExplanationCopy.onDeviceAvailable,
        OnDeviceArchitectureCopy.architectureBody,
      );
      expect(
        OnDeviceAiExplanationCopy.remoteIsOptIn,
        PrivacyClaimCatalogue.remoteProcessingIsAChoice,
      );
    });

    test('every block passes the privacy copy policy', () {
      for (final block in [
        OnDeviceAiExplanationCopy.heading,
        OnDeviceAiExplanationCopy.title,
        OnDeviceAiExplanationCopy.lede,
        OnDeviceAiExplanationCopy.body,
        OnDeviceAiExplanationCopy.continueCta,
        OnDeviceAiExplanationCopy.understandCta,
        OnDeviceAiExplanationCopy.cancelCta,
        ...OnDeviceAiExplanationCopy.bullets,
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(block),
          isEmpty,
          reason: block,
        );
      }
    });

    test('does not ship the requested absolute cloud claim', () {
      final lower = _fullExplanationText.toLowerCase();
      expect(lower, isNot(contains('never goes to the cloud')));
      expect(lower, isNot(contains('entirely on your device')));
      expect(lower, isNot(contains('stays on your phone')));
      expect(lower, isNot(contains('never leaves your phone')));
      expect(lower, isNot(contains('processes everything directly on this device')));
      expect(_fullExplanationText, isNot(contains(_requestedFalseAbsolute)));
      expect(_fullExplanationText, isNot(contains(_requestedFalseOnDeviceBody)));
    });

    test('the policy still flags the leave-the-device shape of that claim', () {
      // "never goes to the cloud" is not in the egress-verb list; the
      // equivalent claim that *is* scanned is "never leave".
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Your recordings never leave your device.',
        ),
        isNotEmpty,
      );
    });

    test('frames on-device as the default, not the whole story', () {
      expect(
        OnDeviceAiExplanationCopy.title.toLowerCase(),
        contains('by default'),
      );
      expect(
        OnDeviceAiExplanationCopy.onDeviceAvailable.toLowerCase(),
        contains('by default'),
      );
      expect(
        OnDeviceAiExplanationCopy.remoteIsOptIn.toLowerCase(),
        contains('unless you choose'),
      );
    });
  });
}
