import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/archive_ownership_copy.dart';
import 'package:voicememory_mobile/features/archive_export/archive_privacy_summary.dart';
import 'package:voicememory_mobile/features/archive_export/complete_archive_export.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/contextual_paywall_policy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

/// Surfaces that must show the ownership promises.
///
/// Onboarding is deliberately absent: its single page body is pinned to
/// `CoreProductVision.valueProposition` by the positioning guards, so the
/// promises have to reach first use through the onboarding screen rather than
/// by appending to that canonical string.
const _promiseSurfaces = [
  'lib/screens/privacy_screen.dart',
  'lib/widgets/account/privacy_trust_centre_screen.dart',
  'lib/screens/export_screen.dart',
];

/// Surfaces that must show the privacy summary itself.
const _summarySurfaces = [
  'lib/screens/privacy_screen.dart',
  'lib/widgets/account/privacy_trust_centre_screen.dart',
];

String _read(String path) => File(path).readAsStringSync();

String _summaryText() => [
  ArchivePrivacySummary.title,
  ArchivePrivacySummary.intro,
  for (final fact in ArchivePrivacySummary.facts) '${fact.title} ${fact.body}',
].join('\n');

void main() {
  group('ownership promises', () {
    test('wording is exact', () {
      expect(
        ArchiveOwnershipCopy.recordingsStayYours,
        'Your recordings stay yours.',
      );
      expect(
        ArchiveOwnershipCopy.interpretationsCorrectable,
        "ArchiveMe's interpretations can be corrected or hidden.",
      );
      expect(
        ArchiveOwnershipCopy.transcriptionChoice,
        'Choose on-device or online transcription.',
      );
      expect(
        ArchiveOwnershipCopy.exportOrDeleteAnytime,
        'Export or delete your archive at any time.',
      );
      expect(ArchiveOwnershipCopy.all, hasLength(4));
    });

    test('the whole set stays short enough for a first-use surface', () {
      // Four short lines, not a privacy essay.
      expect(ArchiveOwnershipCopy.all.join(' ').length, lessThan(220));
    });

    for (final path in _promiseSurfaces) {
      test('$path surfaces the ownership promises', () {
        expect(
          _read(path),
          contains('ArchiveOwnershipCopy.all'),
          reason:
              '$path must render every promise, not a hand-copied subset that '
              'can drift.',
        );
      });
    }

    test('promises would survive the consumer privacy copy guard', () {
      for (final promise in ArchiveOwnershipCopy.all) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(promise),
          isEmpty,
          reason: promise,
        );
      }
    });
  });

  group('privacy summary', () {
    test('covers all seven required facts', () {
      expect(ArchivePrivacySummary.facts, hasLength(7));
      expect(
        ArchivePrivacySummary.facts.map((fact) => fact.title),
        containsAll([
          ArchivePrivacySummary.originals.title,
          ArchivePrivacySummary.onDeviceTranscription.title,
          ArchivePrivacySummary.onlineProcessing.title,
          ArchivePrivacySummary.encryption.title,
          ArchivePrivacySummary.analytics.title,
          ArchivePrivacySummary.export.title,
          ArchivePrivacySummary.deletion.title,
        ]),
      );
    });

    test('states that originals remain user-owned', () {
      expect(
        ArchivePrivacySummary.originals.body,
        contains(ArchiveOwnershipCopy.recordingsStayYours),
      );
      expect(
        ArchivePrivacySummary.originals.body,
        contains('never needs a subscription'),
      );
    });

    test('states that on-device transcription is available', () {
      expect(
        ArchivePrivacySummary.onDeviceTranscription.body,
        contains('local speech model'),
      );
      expect(
        ArchivePrivacySummary.onDeviceTranscription.body,
        contains('without leaving this device'),
      );
    });

    test('names transcription and interpretation as the remote work', () {
      final body = ArchivePrivacySummary.onlineProcessing.body;
      expect(body, contains('transcription'));
      expect(body, contains('interpretation'));
      expect(body, contains('run on servers'));
      expect(
        body.toLowerCase(),
        isNot(contains('local-only')),
        reason: 'processing is not local-only and must not be described so',
      );
    });

    test('describes encryption accurately and never claims end-to-end', () {
      final body = ArchivePrivacySummary.encryption.body;
      expect(body, contains('AES-256-GCM'));
      expect(body, contains('platform secure storage'));
      expect(body, contains('archive file on this device is encrypted'));
      expect(body, contains('encrypted before it is sent'));
      expect(body, contains('a key this device keeps'));
      expect(body, contains('never escrowed'));
      expect(body, contains('not end-to-end encryption'));

      final summary = _summaryText().toLowerCase();
      for (final overclaim in const [
        'end-to-end encrypted',
        'end to end encrypted',
        'e2ee',
        'zero knowledge',
        'zero-knowledge',
        'only you can read',
        'nothing ever leaves your device',
      ]) {
        expect(summary, isNot(contains(overclaim)), reason: overclaim);
      }
    });

    test('states the analytics exclusions', () {
      final body = ArchivePrivacySummary.analytics.body;
      expect(body, contains('never recordings'));
      expect(body, contains('email addresses'));
      expect(body, contains('account tokens'));
    });

    test('states what export and deletion do', () {
      expect(ArchivePrivacySummary.export.body, contains('machine-readable'));
      expect(ArchivePrivacySummary.export.body, contains('Changes history'));
      expect(
        ArchivePrivacySummary.deletion.body,
        contains('removes its text and its audio from this device'),
      );
      expect(
        ArchivePrivacySummary.deletion.body,
        contains('destroys the audio vault key'),
      );
    });

    test('every fact would survive the consumer privacy copy guard', () {
      for (final fact in ArchivePrivacySummary.facts) {
        for (final literal in [fact.title, fact.body]) {
          expect(
            PrivacyCopyPolicy.violationsInLiteral(literal),
            isEmpty,
            reason: literal,
          );
        }
      }
    });

    for (final path in _summarySurfaces) {
      test('$path renders the privacy summary', () {
        final source = _read(path);
        expect(source, contains('ArchivePrivacySummary.facts'));
        expect(source, contains('ArchivePrivacySummary.title'));
      });
    }
  });

  group('export is never gated', () {
    test('exporting originals is user-owned and never paywalled', () {
      final policy = MonetizationPolicy.capability(
        CapabilityId.exportOriginalContent,
      );
      expect(policy.accessClass, AccessClass.userOwned);
      expect(policy.expiryBehaviour, 'alwaysAvailable');
      expect(
        ContextualPaywallPolicy.neverPaywalled,
        contains(CapabilityId.exportOriginalContent),
      );
      expect(
        ContextualPaywallPolicy.mayPaywall(CapabilityId.exportOriginalContent),
        isFalse,
      );
    });

    test('every entitlement state can export', () {
      for (final entitlement in const [
        EntitlementSnapshot.free(),
        EntitlementSnapshot.unknown(),
      ]) {
        final decision = AccessPolicyEngine.decide(
          capability: CapabilityId.exportOriginalContent,
          entitlement: entitlement,
        );
        expect(decision.allowed, isTrue);
        expect(decision.reason, AccessDecisionReason.userOwned);
      }
    });

    test('the export screen says so in the export itself', () {
      expect(
        ArchiveExportManifest.accessNote,
        contains('No subscription is required'),
      );
      expect(
        _read('lib/screens/export_screen.dart'),
        contains('ArchiveExportManifest.accessNote'),
      );
    });
  });
}
