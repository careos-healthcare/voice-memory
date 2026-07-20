import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/comparison_output_parser.dart';

void main() {
  late ComparisonOutputParser parser;

  setUp(() {
    parser = const ComparisonOutputParser();
  });

  const sampleOutput = '''
---
Label: Clear repeat
Connection: This may connect to saying yes before checking capacity.
Evidence:
- Past: "I said yes again before I checked my calendar."
- Present: "I said yes at work without thinking."
What Changed: The repeat showed up around work again with similar wording.
---
''';

  group('ComparisonOutputParser', () {
    test('parses manifesto structure into structured fields', () {
      final parsed = parser.parse(sampleOutput);

      expect(parsed.state, PatternState.clearRepeat);
      expect(
        parsed.connectionText,
        'This may connect to saying yes before checking capacity.',
      );
      expect(parsed.pastQuote, 'I said yes again before I checked my calendar.');
      expect(parsed.currentQuote, 'I said yes at work without thinking.');
      expect(
        parsed.whatChangedText,
        'The repeat showed up around work again with similar wording.',
      );
    });

    test('maps all supported labels to PatternState values', () {
      expect(
        parser.parse('Label: Early signal').state,
        PatternState.earlySignal,
      );
      expect(
        parser.parse('Label: Possible repeat').state,
        PatternState.possibleRepeat,
      );
      expect(
        parser.parse('Label: Still current').state,
        PatternState.stillCurrent,
      );
      expect(
        parser.parse('Label: Not enough evidence').state,
        PatternState.notEnoughEvidence,
      );
      expect(
        parser.parse('Label: Softened').state,
        PatternState.softened,
      );
    });

    test('uses cautious fallbacks when sections are missing', () {
      final parsed = parser.parse('Connection: ');

      expect(parsed.state, PatternState.notEnoughEvidence);
      expect(parsed.connectionText, 'A repeating thread may be forming.');
      expect(parsed.whatChangedText, 'ArchiveMe needs more moments to be sure.');
    });
  });

  group('ComparisonOutputParser - Robustness Test Harness', () {
    test('should parse correctly despite missing colons or extra spaces', () {
      const malformedInput = '''
      Label Clear Repeat
      Connection Found a deep recurring loop here.
      Evidence:
      - Past "I am exhausted by chores"
      - Present "Too many chores today"
      What Changed An intense pile-up of routine duties.
      ''';

      final result = parser.parse(malformedInput);

      expect(result.state, PatternState.clearRepeat);
      expect(result.pastQuote, 'I am exhausted by chores');
      expect(result.currentQuote, 'Too many chores today');
    });

    test('should strip accidental markdown backticks and code fence shells', () {
      const blockyInput = '''
      ```markdown
      LABEL: Softened
      CONNECTION: Thought shifting away from stress.
      EVIDENCE:
      - Past: "I hate commuting"
      - Present: "The train ride was peaceful"
      WHAT CHANGED: Transitioning into appreciation.
      ```
      ''';

      final result = parser.parse(blockyInput);

      expect(result.state, PatternState.softened);
      expect(result.pastQuote, 'I hate commuting');
      expect(result.currentQuote, 'The train ride was peaceful');
    });

    test('should capture long multi-line paragraphs in the What Changed block',
        () {
      const longInput = '''
      Label: Changed
      Connection: Distinct focus shift detected.
      Evidence:
      - Past: "Initial thought text"
      - Present: "Secondary thought text"
      What Changed:
      First line of extensive reasoning analysis.
      Second line containing deeper reflective conclusions.
      Third line finishing out the block.
      ''';

      final result = parser.parse(longInput);

      expect(result.whatChangedText, contains('First line'));
      expect(result.whatChangedText, contains('Third line finishing out the block.'));
    });
  });
}
