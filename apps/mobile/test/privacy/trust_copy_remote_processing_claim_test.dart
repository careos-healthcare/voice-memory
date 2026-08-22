import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_trust_copy.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the promise that remote processing only happens on request.
///
/// `PrivacySecurityTrustCopy.onDeviceProcessingBody` shipped saying cloud
/// processing was "a rare fallback when local confidence is low". Nothing
/// sends on its own, so a user who declined at onboarding was reading, in
/// Settings, that their recordings went to a server anyway. The cases below
/// pin both halves: the consent architecture that makes the claim false, and
/// the absence of the claim from every trust surface that could carry it.
void main() {
  /// Every user-visible trust string that describes where recordings go.
  const trustCopy = <String, String>{
    'PrivacySecurityTrustCopy.onDeviceProcessingTitle':
        PrivacySecurityTrustCopy.onDeviceProcessingTitle,
    'PrivacySecurityTrustCopy.onDeviceProcessingBody':
        PrivacySecurityTrustCopy.onDeviceProcessingBody,
    'PrivacySecurityTrustCopy.encryptedAtRestTitle':
        PrivacySecurityTrustCopy.encryptedAtRestTitle,
    'PrivacySecurityTrustCopy.encryptedAtRestBody':
        PrivacySecurityTrustCopy.encryptedAtRestBody,
    'PrivacySecurityTrustCopy.linkOnDeviceToggle':
        PrivacySecurityTrustCopy.linkOnDeviceToggle,
    'TrustBadgeCopy.onDeviceProcessing': TrustBadgeCopy.onDeviceProcessing,
    'TrustBadgeCopy.onDeviceDetail': TrustBadgeCopy.onDeviceDetail,
    'TrustBadgeCopy.storage': TrustBadgeCopy.storage,
    'TrustBadgeCopy.storageDetail': TrustBadgeCopy.storageDetail,
    'OnDeviceArchitectureCopy.architectureBody':
        OnDeviceArchitectureCopy.architectureBody,
    'OnDeviceArchitectureCopy.storageBody': OnDeviceArchitectureCopy.storageBody,
    'OnDeviceArchitectureCopy.remoteCallout':
        OnDeviceArchitectureCopy.remoteCallout,
    'OnDeviceProcessingCopy.subtitle': OnDeviceProcessingCopy.subtitle,
    'OnDeviceProcessingCopy.body': OnDeviceProcessingCopy.body,
    'PrivacyScreenCopy.intro': PrivacyScreenCopy.intro,
    'PrivacyScreenCopy.privateByDefaultBody':
        PrivacyScreenCopy.privateByDefaultBody,
    'PrivacyScreenCopy.aiProcessingBody': PrivacyScreenCopy.aiProcessingBody,
    'PrivacyScreenCopy.remoteProcessingSwitchBodyOn':
        PrivacyScreenCopy.remoteProcessingSwitchBodyOn,
    'PrivacyScreenCopy.remoteProcessingSwitchBodyOff':
        PrivacyScreenCopy.remoteProcessingSwitchBodyOff,
  };

  /// Words that describe work leaving the device.
  const remoteWords = ['cloud', 'server', 'remote'];

  /// Words that would make that work sound like something the app decides.
  const unpromptedWords = [
    'fallback',
    'falls back',
    'automatic',
    'automatically',
    'on its own',
    'behind the scenes',
  ];

  group('remote processing is described as a choice, not a fallback', () {
    test('no trust string calls remote work automatic or a fallback', () {
      trustCopy.forEach((name, copy) {
        final lower = copy.toLowerCase();
        if (!remoteWords.any(lower.contains)) return;
        for (final word in unpromptedWords) {
          expect(
            lower,
            isNot(contains(word)),
            reason:
                '$name describes remote processing as "$word". Remote work '
                'only happens after an explicit per-purpose grant, so copy '
                'must not present it as something the app initiates.',
          );
        }
      });
    });

    test('"fallback" appears on no trust surface at all', () {
      trustCopy.forEach((name, copy) {
        expect(
          copy.toLowerCase(),
          isNot(contains('fallback')),
          reason: '$name still frames remote processing as a fallback.',
        );
      });
    });

    test('the settings trust block carries the opt-in promise verbatim', () {
      expect(
        PrivacySecurityTrustCopy.onDeviceProcessingBody,
        contains(PrivacyCopyPolicy.nothingSentUnlessFeatureChosen),
        reason:
            'The promise is worded once, in PrivacyCopyPolicy. A fourth '
            'independent wording is how the fallback claim survived.',
      );
    });
  });

  group('the architecture the copy depends on', () {
    test('on-device processing is the default', () {
      expect(OnDeviceProcessingStore.defaultEnabled, isTrue);
    });

    test('unset remote consent grants nothing', () {
      expect(RemoteProcessingConsentState.unset.consented, isFalse);
      expect(RemoteProcessingConsentState.unset.grantedPurposes, isEmpty);
    });

    test('every purpose is refused while consent is unset', () {
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(
          RemoteProcessingConsentState.unset.isPurposeGranted(purpose),
          isFalse,
          reason:
              'If this ever passes, the settings copy promising an explicit '
              'per-purpose grant becomes false and has to change with it.',
        );
      }
    });
  });
}
