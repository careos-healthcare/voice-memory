import 'package:archiveme_mobile/features/patterns/legacy_pattern_copy_guard.dart';
import 'package:archiveme_mobile/features/patterns/pattern_copy_quality_gate.dart';
import 'package:archiveme_mobile/features/patterns/pattern_display_copy_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyPatternCopyGuard', () {
    test('detects legacy template substrings', () {
      for (final bad in [
        'You may do more when pressure from what you feel you should do.',
        'The pressure seems to return around pressure from what you feel you should do.',
        'Record another ordinary moment and notice whether pressure from what you feel you should do shows up again.',
        'The repeated thread may be pressure from what you feel you should do.',
        'follow a heavy should',
        'test to see if',
      ]) {
        expect(
          LegacyPatternCopyGuard.containsLegacyCopy(bad),
          isTrue,
          reason: bad,
        );
      }
    });

    test('allows natural trailing want-to phrases', () {
      const sentence =
          'When pressure builds, you seem to push yourself to keep going — even when part of you does not want to.';
      expect(LegacyPatternCopyGuard.hasNaturalTrailingPhrase(sentence), isTrue);
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.currentBelief,
          sentence,
        ).approved,
        isTrue,
      );
      expect(
        PatternCopyQualityGate.gate(
          sentence,
          role: PatternCopyRole.sentence,
        ).usedFallback,
        isFalse,
      );
    });
  });
}