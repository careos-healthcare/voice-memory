import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

void main() {
  group('PrivacyCopyPolicy constants', () {
    test('allowed promises match the canonical wording', () {
      expect(PrivacyCopyPolicy.privateByDefault, 'Private by default');
      expect(
        PrivacyCopyPolicy.nothingSentUnlessChosen,
        'Nothing is sent unless you choose cloud, sync, or transcription.',
      );
      expect(
        PrivacyCopyPolicy.exportDeleteAnytime,
        'You can export or delete your local archive at any time.',
      );
      expect(PrivacyCopyPolicy.lockArchiveMe, 'Protect this archive');
    });
  });

  group('PrivacyCopyPolicy literal guards', () {
    test('flags never sent without unless you choose', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral('Your data is never sent'),
        isNotEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          PrivacyCopyPolicy.nothingSentUnlessChosen,
        ),
        isEmpty,
      );
    });

    test('flags unsafe security superlatives', () {
      for (final bad in const [
        '100% secure',
        'military grade encryption',
        'military-grade protection',
        'unhackable vault',
        'unbreakable privacy',
        'impossible to access without permission',
        'nothing ever leaves your device',
        'delete from every server instantly',
        'all journal data is encrypted',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(bad),
          isNotEmpty,
          reason: 'should reject "$bad"',
        );
      }
    });

    test('flags anonymous unless explicitly supported', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral('Your archive is anonymous'),
        isNotEmpty,
      );
    });

    test('allows encrypted backup and sync copy only in supported contexts', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'If you sign in and enable sync, backup data is encrypted before it is stored.',
        ),
        isEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Sign in with email to encrypt a backup of what you built on this device.',
        ),
        isEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Your entries are encrypted on this device.',
        ),
        isNotEmpty,
      );
    });
  });

  group('Consumer privacy copy scan', () {
    for (final path in PrivacyCopyPolicy.consumerPrivacySources) {
      test('$path has no unsafe privacy promises', () {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
        final source = File(path).readAsStringSync();
        final violations = PrivacyCopyPolicy.scanFile(path, source);
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    }
  });
}
