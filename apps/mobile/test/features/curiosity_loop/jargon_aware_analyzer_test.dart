import 'package:archiveme_mobile/features/curiosity_loop/domain/services/jargon_aware_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JargonAwareAnalyzer', () {
    const analyzer = JargonAwareAnalyzer();

    test('returns 0.0 for empty input', () {
      expect(analyzer.calculateNormalizedTtr(''), 0.0);
      expect(analyzer.calculateNormalizedTtr('   '), 0.0);
    });

    test('calculates normal TTR for standard text', () {
      expect(
        analyzer.calculateNormalizedTtr('the cat sat on the mat'),
        closeTo(5 / 6, 0.0001),
      );
      expect(
        analyzer.calculateNormalizedTtr('the the the cat'),
        closeTo(0.5, 0.0001),
      );
    });

    test('collapses multi-word clinical terms into single tokens', () {
      final jargonAwareTtr = analyzer.calculateNormalizedTtr(
        'cognitive behavioral therapy helps the the the',
      );
      const naiveWordCountTtr = 5 / 7;

      expect(jargonAwareTtr, closeTo(3 / 5, 0.0001));
      expect(jargonAwareTtr, isNot(closeTo(naiveWordCountTtr, 0.0001)));
    });

    test('handles messy punctuation and internal hyphens cleanly', () {
      expect(
        analyzer.calculateNormalizedTtr(
          'Cognitive-Behavioral, therapy—serotonin reuptake! '
          'and executive-function / executive function.',
        ),
        closeTo(1.0, 0.0001),
      );
      expect(
        analyzer.calculateNormalizedTtr(
          'self-regulation, self-regulation, executive function',
        ),
        closeTo(2 / 3, 0.0001),
      );
    });
  });
}