import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Absolute claims this screen must never make again.
///
/// The hero exists because an earlier draft promised "all processing happens
/// 100% on your device", "zero data is ever sent", and "your recordings never
/// leave your device" — none of which this codebase supports. A production
/// backend is configured in `config/backend_url.txt`, `/api/transcribe` takes
/// multipart audio, and the very previous onboarding screen asks permission to
/// use it.
///
/// The policy's scanner now catches this shape too — its absolute-claim rule
/// rejects "zero data is ever sent" and "100% on your device", which the older
/// `never sent|never leaves` trigger passed. This list stays because it is a
/// phrase-exact record of what this screen said and must not say again, which
/// is a different job from the general rule.
const _bannedAbsoluteClaims = <String>[
  '100%',
  'zero data',
  'zero cloud',
  'never leaves',
  'never leave',
  'never sent',
  'nothing ever leaves',
  'never used to train',
  'not used to train',
  'no cloud',
  'no servers',
  'entirely on this device',
  'only on this device',
  'only on your device',
  'all processing happens',
];

/// Claims that need a runtime fact or a third party this repository cannot
/// vouch for. Storage protection is a runtime flag
/// (`SecureSqliteLockService.encryptionEnabled`, which has an "unavailable"
/// state, further gated on `Platform.isIOS || Platform.isAndroid`); the journal
/// and the index that searches it are different engines with different
/// protection; and nothing here can speak for whatever processes
/// `/api/transcribe`.
const _unsubstantiatedTerms = <String>[
  'encrypt',
  'sqlite',
  'sqlcipher',
  'openai',
  'anthropic',
  'anonymous',
  'training',
];

/// Encryption claims that overstate their subject or drop their platform scope.
///
/// The rule used to be written out here, which meant it guarded this screen
/// and nothing else. It now lives in [PrivacyCopyPolicy] and applies repo-wide;
/// this alias keeps the cases below reading the same way.
List<String> unscopedEncryptionViolations(String text) =>
    PrivacyCopyPolicy.unscopedEncryptionViolations(text);

/// Every phrase in [_bannedAbsoluteClaims] or [_unsubstantiatedTerms] that
/// [text] contains, plus a bare-word check for the banned product term.
List<String> absoluteClaimViolations(String text) {
  final lower = text.toLowerCase();
  return [
    for (final phrase in [..._bannedAbsoluteClaims, ..._unsubstantiatedTerms])
      if (lower.contains(phrase)) phrase,
    if (RegExp(r'\bai\b').hasMatch(lower)) 'ai',
  ];
}

/// Everything a customer reads on the hero, in reading order.
String get _fullHeroText => [
  OnDeviceHeroCopy.eyebrow,
  OnDeviceHeroCopy.title,
  OnDeviceHeroCopy.lede,
  for (final pillar in OnDeviceHeroCopy.pillars) '${pillar.title} ${pillar.body}',
  OnDeviceHeroCopy.storageStatusHeading,
  OnDeviceHeroCopy.storageStatusBody,
  OnDeviceHeroCopy.detailLink,
  OnDeviceHeroCopy.continueCta,
].join(' ');

void main() {
  group('OnDeviceHeroCopy', () {
    test('states exactly three pillars', () {
      expect(OnDeviceHeroCopy.pillars, hasLength(3));
      for (final pillar in OnDeviceHeroCopy.pillars) {
        expect(pillar.title, isNotEmpty);
        expect(pillar.body, isNotEmpty);
      }
    });

    test('passes the privacy copy policy block by block', () {
      for (final block in [
        OnDeviceHeroCopy.eyebrow,
        OnDeviceHeroCopy.title,
        OnDeviceHeroCopy.lede,
        OnDeviceHeroCopy.storageStatusHeading,
        OnDeviceHeroCopy.storageStatusBody,
        OnDeviceHeroCopy.detailLink,
        OnDeviceHeroCopy.continueCta,
        for (final pillar in OnDeviceHeroCopy.pillars) ...[
          pillar.title,
          pillar.body,
        ],
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(block),
          isEmpty,
          reason: block,
        );
      }
    });

    group('regression guard against absolute claims', () {
      // This is the point of the whole screen: if someone reintroduces one of
      // the original promises, this fails before it ships.
      test('the hero makes none of them', () {
        expect(
          absoluteClaimViolations(_fullHeroText),
          isEmpty,
          reason: _fullHeroText,
        );
      });

      test('the guard actually catches the claims it replaced', () {
        // A guard that passes everything is worse than no guard, so assert it
        // rejects the exact wording this screen was built to avoid.
        const originals = [
          'Local Execution: All AI processing happens 100% on your device '
              'hardware—zero data is ever sent to external cloud servers.',
          'Zero Cloud Footprint: Your voice recordings, transcripts, and '
              'insights never leave your device.',
          'No AI Training: Your personal data is never used to train machine '
              'learning models.',
        ];
        for (final claim in originals) {
          expect(
            absoluteClaimViolations(claim),
            isNotEmpty,
            reason: claim,
          );
        }
      });

      test('does not assert storage protection as a fixed fact', () {
        // The hero points at the live status card instead. Asserting it here
        // would be wrong in any build where encryption is unavailable.
        expect(_fullHeroText.toLowerCase(), isNot(contains('encrypt')));
        expect(
          OnDeviceHeroCopy.storageStatusBody,
          PrivacyClaimCatalogue.storageProtectionReportedLive,
        );
        expect(
          OnDeviceHeroCopy.storageStatusBody.toLowerCase(),
          contains('instead of asserting it here'),
        );
      });

      test('names no storage engine', () {
        final lower = _fullHeroText.toLowerCase();
        for (final engine in ['sqlite', 'sqlcipher']) {
          expect(lower, isNot(contains(engine)));
        }
      });

      test('names no third-party processor', () {
        final lower = _fullHeroText.toLowerCase();
        expect(lower, isNot(contains('openai')));
        expect(lower, isNot(contains('anthropic')));
      });
    });

    group('the claims it does make', () {
      test('frames on-device as the default, not the whole story', () {
        expect(
          OnDeviceHeroCopy.title.toLowerCase(),
          contains('by default'),
        );
        expect(
          OnDeviceHeroCopy.pillarLocalTitle.toLowerCase(),
          contains('by default'),
        );
        expect(
          OnDeviceHeroCopy.pillarLocalBody.toLowerCase(),
          contains('by default'),
        );
      });

      test('frames remote processing as an opt-in with a named off switch', () {
        final lower = OnDeviceHeroCopy.pillarRemoteBody.toLowerCase();
        expect(lower, contains('unless you choose'));
        expect(lower, contains('turn it off'));
        expect(OnDeviceHeroCopy.pillarRemoteTitle, contains('opt-in'));
      });

      test('names the features that use the server', () {
        final lower = OnDeviceHeroCopy.pillarRemoteBody.toLowerCase();
        expect(lower, contains('transcription'));
        expect(lower, contains('sync'));
      });

      test('scopes the third pillar to what the analytics guard enforces', () {
        // Replaces the unsubstantiable training claim. `ProofAnalyticsGuard`
        // refuses `transcript` and `quote` keys outright and drops any value
        // that is not bool, num, or id-shaped, so "counts, not content" is a
        // boundary the code actually implements.
        expect(
          OnDeviceHeroCopy.pillarAnalyticsTitle.toLowerCase(),
          contains('counts'),
        );
        expect(
          OnDeviceHeroCopy.pillarAnalyticsBody.toLowerCase(),
          contains('not your words'),
        );
        expect(
          OnDeviceHeroCopy.pillarAnalyticsBody.toLowerCase(),
          isNot(contains('train')),
        );
      });
    });

    group('shared wording is reused, not restated', () {
      test('every pillar body is the settings statement verbatim', () {
        expect(
          OnDeviceHeroCopy.pillarLocalBody,
          OnDeviceArchitectureCopy.architectureBody,
        );
        expect(
          OnDeviceHeroCopy.pillarRemoteBody,
          OnDeviceArchitectureCopy.remoteCallout,
        );
        expect(
          OnDeviceHeroCopy.pillarAnalyticsBody,
          OnDeviceArchitectureCopy.analyticsBody,
        );
        expect(
          OnDeviceHeroCopy.storageStatusBody,
          OnDeviceArchitectureCopy.storageBody,
        );
      });

      test('two of three pillar titles reuse the settings headings', () {
        expect(
          OnDeviceHeroCopy.pillarLocalTitle,
          OnDeviceArchitectureCopy.architectureHeading,
        );
        expect(
          OnDeviceHeroCopy.pillarRemoteTitle,
          OnDeviceArchitectureCopy.remoteHeading,
        );
      });

      test('the sensitive promise still comes from the policy', () {
        expect(
          OnDeviceHeroCopy.pillarRemoteBody,
          startsWith(PrivacyCopyPolicy.nothingSentUnlessFeatureChosen),
        );
      });

      test('shared actions reuse their existing labels', () {
        expect(
          OnDeviceHeroCopy.detailLink,
          RemoteProcessingConsentCopy.moreDetailLink,
        );
        expect(OnDeviceHeroCopy.continueCta, OnboardingV1Copy.startCta);
      });
    });

    group('regression guard against unscoped encryption claims', () {
      /// Everything a customer can read that carries the encryption baseline.
      final shipped = <String, String>{
        'PrivacyCopyPolicy.encryptedAtRestScoped':
            PrivacyCopyPolicy.encryptedAtRestScoped,
        'PrivacyCopyPolicy.encryptionBaselineDetail':
            PrivacyCopyPolicy.encryptionBaselineDetail,
        'TrustStatusFooterCopy.encryptedAtRest':
            TrustStatusFooterCopy.encryptedAtRest,
        'TrustStatusFooterCopy.encryptedSemanticLabel':
            TrustStatusFooterCopy.encryptedSemanticLabel,
        'PrivacyCopyPolicy.journalEncryptedAtRestPromise':
            PrivacyCopyPolicy.journalEncryptedAtRestPromise,
      };

      test('the shipped encryption copy is scoped', () {
        shipped.forEach((name, text) {
          expect(unscopedEncryptionViolations(text), isEmpty, reason: name);
        });
      });

      test('the guard rejects the wording it replaced', () {
        // The string originally requested, plus the two claims that were
        // already in the tree and false as written. A guard that passes these
        // would be decoration.
        const rejected = [
          'Secured with AES-256 local SQLite encryption. Your data is '
              'encrypted at rest and can only be unlocked locally.',
          'Your data is encrypted at rest and can only be unlocked locally',
          'Encrypted at Rest',
          'Encrypted at rest. Local journal storage and the SQLite vault are '
              'encrypted on this device.',
          'Journal content on this device is encrypted at rest.',
          'Encryption at rest is always on.',
        ];
        for (final claim in rejected) {
          expect(
            unscopedEncryptionViolations(claim),
            isNotEmpty,
            reason: claim,
          );
        }
      });

      test('the shipped encryption copy passes the privacy copy policy', () {
        shipped.forEach((name, text) {
          expect(
            PrivacyCopyPolicy.violationsInLiteral(text),
            isEmpty,
            reason: name,
          );
        });
      });

      test('the policy still reports encryption claims it has not approved', () {
        // The two approved contexts are anchored or phrase-specific, so
        // widening them stays a deliberate act rather than a side effect.
        for (final claim in const [
          'Encrypted at Rest',
          'Your data is encrypted at rest and can only be unlocked locally.',
          'Everything on this device is encrypted.',
        ]) {
          expect(
            PrivacyCopyPolicy.violationsInLiteral(claim),
            isNotEmpty,
            reason: claim,
          );
        }
      });

      test('names the platforms the database half depends on', () {
        final lower = PrivacyCopyPolicy.encryptionBaselineDetail.toLowerCase();
        expect(lower, contains('ios'));
        expect(lower, contains('android'));
        // Says what it does not cover, so it cannot be read as covering disk.
        expect(lower, contains('not covered'));
        expect(lower, isNot(contains('your data')));
      });

      test('the hero keeps pointing at live status instead of the badge', () {
        // The static baseline and the live `EncryptionStatusCard` can only
        // coexist while the hero asserts nothing: on a build where encryption
        // is unavailable, a static badge beside that card would contradict it.
        expect(_fullHeroText.toLowerCase(), isNot(contains('encrypt')));
        expect(
          absoluteClaimViolations(PrivacyCopyPolicy.encryptedAtRestScoped),
          isNotEmpty,
          reason: 'hero guard must keep treating encryption copy as off-limits',
        );
      });
    });

    test('quotes are plain ASCII with no escape artifact', () {
      expect(_fullHeroText, isNot(contains(r'\')));
      expect(_fullHeroText, isNot(contains('\u2018')));
      expect(_fullHeroText, isNot(contains('\u2019')));
    });
  });
}
