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

String get _fullDisclosureText => [
  OnDeviceAiDisclosureCopy.heading,
  OnDeviceAiDisclosureCopy.title,
  OnDeviceAiDisclosureCopy.lede,
  OnDeviceAiDisclosureCopy.body,
  ...OnDeviceAiDisclosureCopy.bullets,
  OnDeviceAiDisclosureCopy.continueCta,
  OnDeviceAiDisclosureCopy.understandCta,
  OnDeviceAiDisclosureCopy.cancelCta,
].join(' ');

void main() {
  group('OnDeviceAiDisclosureCopy', () {
    test('OnDeviceAiExplanationCopy remains a typedef of the disclosure copy', () {
      expect(OnDeviceAiExplanationCopy.title, OnDeviceAiDisclosureCopy.title);
      expect(OnDeviceAiExplanationCopy.lede, OnDeviceAiDisclosureCopy.lede);
    });

    test('aliases the live hero and architecture statements', () {
      expect(OnDeviceAiDisclosureCopy.title, OnDeviceHeroCopy.title);
      expect(OnDeviceAiDisclosureCopy.lede, OnDeviceHeroCopy.lede);
      expect(
        OnDeviceAiDisclosureCopy.journalDefault,
        PrivacyClaimCatalogue.momentsStayLocal,
      );
      expect(
        OnDeviceAiDisclosureCopy.onDeviceAvailable,
        OnDeviceArchitectureCopy.architectureBody,
      );
      expect(
        OnDeviceAiDisclosureCopy.remoteIsOptIn,
        PrivacyClaimCatalogue.remoteProcessingIsAChoice,
      );
    });

    test('the screen body aliases the live default-and-choice claims', () {
      expect(
        OnDeviceAiDisclosureCopy.body,
        '${OnDeviceHeroCopy.title} ${PrivacyClaimCatalogue.remoteProcessingIsAChoice}',
      );
    });

    test('every block passes the privacy copy policy', () {
      for (final block in [
        OnDeviceAiDisclosureCopy.heading,
        OnDeviceAiDisclosureCopy.title,
        OnDeviceAiDisclosureCopy.lede,
        OnDeviceAiDisclosureCopy.body,
        OnDeviceAiDisclosureCopy.continueCta,
        OnDeviceAiDisclosureCopy.understandCta,
        OnDeviceAiDisclosureCopy.cancelCta,
        ...OnDeviceAiDisclosureCopy.bullets,
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(block),
          isEmpty,
          reason: block,
        );
      }
    });

    test('does not ship the requested absolute cloud claim', () {
      final lower = _fullDisclosureText.toLowerCase();
      expect(lower, isNot(contains('never goes to the cloud')));
      expect(lower, isNot(contains('entirely on your device')));
      expect(lower, isNot(contains('stays on your phone')));
      expect(lower, isNot(contains('never leaves your phone')));
      expect(lower, isNot(contains('processes everything directly on this device')));
      expect(lower, isNot(contains('works fully offline')));
      expect(lower, isNot(contains('zero third-party sharing')));
      expect(_fullDisclosureText, isNot(contains(_requestedFalseAbsolute)));
      expect(_fullDisclosureText, isNot(contains(_requestedFalseOnDeviceBody)));
    });

    test('the policy still flags the leave-the-device shape of that claim', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Your recordings never leave your device.',
        ),
        isNotEmpty,
      );
    });

    test('frames on-device as the default, not the whole story', () {
      expect(
        OnDeviceAiDisclosureCopy.title.toLowerCase(),
        contains('by default'),
      );
      expect(
        OnDeviceAiDisclosureCopy.onDeviceAvailable.toLowerCase(),
        contains('by default'),
      );
      expect(
        OnDeviceAiDisclosureCopy.remoteIsOptIn.toLowerCase(),
        contains('unless you choose'),
      );
    });
  });
}
