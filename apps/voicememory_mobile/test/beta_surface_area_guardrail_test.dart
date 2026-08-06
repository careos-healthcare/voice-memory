import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

const _guardrailPath = '../../docs/BETA_SURFACE_AREA_GUARDRAIL.md';

const _bannedPhrases = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
  'mental health score',
  'wellbeing score',
  'life score',
  'clinical score',
  'archiveme knows',
  'everything stays on device',
  'fully encrypted archive',
];

bool _isProhibitionLine(String lower) {
  return lower.contains('forbidden') ||
      lower.contains('do not') ||
      lower.contains('guardrail') ||
      lower.contains('unless every');
}

void main() {
  late String guardrail;

  setUpAll(() {
    guardrail = File(_guardrailPath).readAsStringSync();
  });

  group('Beta surface-area guardrail doc', () {
    test('doc exists', () {
      expect(File(_guardrailPath).existsSync(), isTrue);
    });

    test('doc contains canonical beta path', () {
      expect(guardrail.toLowerCase(), contains('save one yes moment'));
      expect(guardrail.toLowerCase(), contains('save two more'));
      expect(guardrail.toLowerCase(), contains('review what repeated'));
    });

    test('under 3 moments show one primary path only', () {
      expect(guardrail.toLowerCase(), contains('under 3 moments'));
      expect(guardrail.toLowerCase(), contains('one primary path'));
    });

    test('historical surfaces must not compete on first run', () {
      expect(
        guardrail.toLowerCase(),
        contains('must not compete on first run'),
      );
    });

    test('paid cues stay suppressed until eligibility', () {
      expect(
        guardrail.toLowerCase(),
        contains('paid cues stay suppressed until eligibility'),
      );
    });

    test('no new dashboards', () {
      expect(guardrail.toLowerCase(), contains('do not add new dashboards'));
    });

    test('passes banned phrase scan', () {
      for (final line in guardrail.split('\n')) {
        final lower = line.toLowerCase();
        if (_isProhibitionLine(lower)) continue;
        for (final phrase in _bannedPhrases) {
          expect(
            lower,
            isNot(contains(phrase)),
            reason: '"$line" contains "$phrase"',
          );
        }
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('privacy violation in "$line": $reason');
        }
      }
    });
  });
}
