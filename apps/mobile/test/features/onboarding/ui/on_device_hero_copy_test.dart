import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Absolute claims this screen must never make again.
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

const _unsubstantiatedTerms = <String>[
  'encrypt',
  'sqlite',
  'sqlcipher',
  'openai',
  'anthropic',
  'anonymous',
  'training',
];

List<String> unscopedEncryptionViolations(String text) =>
    PrivacyCopyPolicy.unscopedEncryptionViolations(text);

List<String> absoluteClaimViolations(String text) {
  final lower = text.toLowerCase();
  return [
    for (final phrase in [..._bannedAbsoluteClaims, ..._unsubstantiatedTerms])
      if (lower.contains(phrase)) phrase,
    if (RegExp(r'\bai\b').hasMatch(lower)) 'ai',
  ];
}

String get _fullHeroText => [
  OnDeviceHeroCopy.allowedTitle,
  OnDeviceHeroCopy.allowedBody,
  OnDeviceHeroCopy.declinedTitle,
  OnDeviceHeroCopy.declinedBody,
  OnDeviceHeroCopy.continueCta,
].join(' ');

void main() {
  group('OnDeviceHeroCopy', () {
    test('confirms the choice instead of restating architecture', () {
      expect(
        OnDeviceHeroCopy.titleFor(allowedRemote: true),
        OnDeviceHeroCopy.allowedTitle,
      );
      expect(
        OnDeviceHeroCopy.bodyFor(allowedRemote: true),
        OnDeviceHeroCopy.allowedBody,
      );
      expect(
        OnDeviceHeroCopy.titleFor(allowedRemote: false),
        OnDeviceHeroCopy.declinedTitle,
      );
      expect(
        OnDeviceHeroCopy.bodyFor(allowedRemote: false),
        OnDeviceHeroCopy.declinedBody,
      );
      expect(OnDeviceHeroCopy.allowedTitle, isNot(OnDeviceHeroCopy.declinedTitle));
    });

    test('passes the privacy copy policy block by block', () {
      for (final block in [
        OnDeviceHeroCopy.allowedTitle,
        OnDeviceHeroCopy.allowedBody,
        OnDeviceHeroCopy.declinedTitle,
        OnDeviceHeroCopy.declinedBody,
        OnDeviceHeroCopy.continueCta,
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(block),
          isEmpty,
          reason: block,
        );
      }
    });

    test('the hero makes none of the retired absolute claims', () {
      expect(
        absoluteClaimViolations(_fullHeroText),
        isEmpty,
        reason: _fullHeroText,
      );
    });

    test('the guard actually catches the claims it replaced', () {
      const originals = [
        'Local Execution: All AI processing happens 100% on your device '
            'hardware—zero data is ever sent to external cloud servers.',
        'Zero Cloud Footprint: Your voice recordings, transcripts, and '
            'insights never leave your device.',
        'No AI Training: Your personal data is never used to train machine '
            'learning models.',
      ];
      for (final claim in originals) {
        expect(absoluteClaimViolations(claim), isNotEmpty, reason: claim);
      }
    });

    test('does not assert storage protection or name an engine', () {
      final lower = _fullHeroText.toLowerCase();
      expect(lower, isNot(contains('encrypt')));
      expect(lower, isNot(contains('sqlite')));
      expect(lower, isNot(contains('sqlcipher')));
      expect(lower, isNot(contains('openai')));
    });

    test('the start action reuses the existing label', () {
      expect(OnDeviceHeroCopy.continueCta, OnboardingV1Copy.startCta);
    });

    test('quotes are plain ASCII with no escape artifact', () {
      expect(_fullHeroText, isNot(contains(r'\')));
      expect(_fullHeroText, isNot(contains('\u2018')));
      expect(_fullHeroText, isNot(contains('\u2019')));
    });
  });

  group('regression guard against unscoped encryption claims', () {
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
      expect(lower, contains('not covered'));
      expect(lower, isNot(contains('your data')));
    });

    test('hero confirmation copy stays off the encryption badge', () {
      expect(_fullHeroText.toLowerCase(), isNot(contains('encrypt')));
      expect(
        absoluteClaimViolations(PrivacyCopyPolicy.encryptedAtRestScoped),
        isNotEmpty,
        reason: 'hero guard must keep treating encryption copy as off-limits',
      );
    });
  });
}
