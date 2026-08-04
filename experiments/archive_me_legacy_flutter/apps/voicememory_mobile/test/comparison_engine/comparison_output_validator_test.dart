import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/comparison_output_parser.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/comparison_output_validator.dart';

void main() {
  const validator = ComparisonOutputValidator(
    maxEvidenceCharacters: 100,
    maxSummaryCharacters: 200,
  );

  ParsedComparisonOutput validOutput({
    PatternState state = PatternState.clearRepeat,
    String? sourceLabel = 'Clear repeat',
    String connection = 'This may connect to a repeated response.',
    String past = 'I agreed before checking.',
    String current = 'I agreed again today.',
    String whatChanged = 'The setting changed while the response remained.',
    double? confidence = 0.75,
    String? confidenceSource,
    String? pastDate,
    String? currentDate,
    bool? sourceHadConnection,
    bool? sourceHadWhatChanged,
    bool? sourceHadEvidence,
  }) {
    return ParsedComparisonOutput(
      state: state,
      connectionText: connection,
      pastQuote: past,
      currentQuote: current,
      whatChangedText: whatChanged,
      sourceLabel: sourceLabel,
      confidence: confidence,
      confidenceSource: confidenceSource,
      pastEvidenceDate: pastDate,
      currentEvidenceDate: currentDate,
      sourceHadConnection: sourceHadConnection,
      sourceHadWhatChanged: sourceHadWhatChanged,
      sourceHadEvidence: sourceHadEvidence,
    );
  }

  Matcher hasCode(ComparisonValidationErrorCode code) =>
      predicate<ComparisonOutputValidationResult>(
        (result) => result.validationErrors.any((error) => error.code == code),
        'contains validation error $code',
      );

  group('ComparisonOutputValidator valid outputs', () {
    test('accepts a completely valid object', () {
      final result = validator.validate(
        validOutput(
          confidenceSource: '0.75',
          pastDate: '2026-01-01T10:00:00Z',
          currentDate: '2026-01-02T10:00:00Z',
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.validationErrors, isEmpty);
      expect(result.severity, isNull);
      expect(result.sanitizedOutput, isNotNull);
    });

    test('accepts minimum not-enough-evidence output', () {
      final result = validator.validate(
        validOutput(
          state: PatternState.notEnoughEvidence,
          sourceLabel: 'Not enough evidence',
          past: '',
          current: '',
          confidence: null,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('accepts values exactly at configured maximums', () {
      final result = validator.validate(
        validOutput(
          connection: _repeat('c', 200),
          past: _repeat('p', 100),
          current: _repeat('n', 100),
          whatChanged: _repeat('w', 200),
          confidence: 1,
          confidenceSource: '1.0',
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.validationErrors, isEmpty);
    });
  });

  group('ComparisonOutputValidator confidence', () {
    for (final value in <double>[-0.01, 1.01]) {
      test('rejects out-of-range value $value', () {
        final result = validator.validate(
          validOutput(confidence: value, confidenceSource: '$value'),
        );
        expect(result.isValid, isFalse);
        expect(
          result,
          hasCode(ComparisonValidationErrorCode.confidenceOutOfRange),
        );
      });
    }

    for (final value in <double>[double.nan, double.infinity]) {
      test('rejects non-finite value $value', () {
        final result = validator.validate(
          validOutput(confidence: value, confidenceSource: '$value'),
        );
        expect(result.isValid, isFalse);
        expect(
          result,
          hasCode(ComparisonValidationErrorCode.nonFiniteConfidence),
        );
      });
    }

    test('rejects malformed supplied confidence', () {
      final result = validator.validate(
        validOutput(confidence: null, confidenceSource: 'high'),
      );
      expect(result.isValid, isFalse);
      expect(
        result,
        hasCode(ComparisonValidationErrorCode.malformedConfidence),
      );
    });
  });

  group('ComparisonOutputValidator labels and enums', () {
    test('rejects unknown label', () {
      final result = validator.validate(validOutput(sourceLabel: 'Certain'));
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.unknownLabel));
    });

    for (final label in <String?>[null, '', '   ']) {
      test('rejects empty label "$label"', () {
        final result = validator.validate(validOutput(sourceLabel: label));
        expect(result.isValid, isFalse);
        expect(result, hasCode(ComparisonValidationErrorCode.missingLabel));
      });
    }

    test('rejects a supported label paired with a contradictory enum', () {
      final result = validator.validate(
        validOutput(state: PatternState.changed, sourceLabel: 'Clear repeat'),
      );
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.contradictoryLabel));
    });

    test('recognises every strongly typed enum value', () {
      for (final state in PatternState.values) {
        final result = validator.validate(
          validOutput(
            state: state,
            sourceLabel: ComparisonOutputValidator.canonicalLabelFor(state),
            past: state == PatternState.notEnoughEvidence ? '' : 'Past.',
            current: state == PatternState.notEnoughEvidence ? '' : 'Current.',
          ),
        );
        expect(result.isValid, isTrue, reason: '$state must remain supported');
      }
    });
  });

  group('ComparisonOutputValidator required fields', () {
    test('rejects missing evidence for a meaningful label', () {
      final result = validator.validate(validOutput(past: '', current: ''));
      expect(result.isValid, isFalse);
      expect(
        result,
        hasCode(ComparisonValidationErrorCode.missingPastEvidence),
      );
      expect(
        result,
        hasCode(ComparisonValidationErrorCode.missingCurrentEvidence),
      );
    });

    test('rejects missing summary', () {
      final result = validator.validate(
        validOutput(connection: '', whatChanged: ''),
      );
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.missingConnection));
      expect(result, hasCode(ComparisonValidationErrorCode.missingWhatChanged));
    });

    test('rejects parser defaults when required source fields were absent', () {
      final result = validator.validate(
        validOutput(sourceHadConnection: false, sourceHadWhatChanged: false),
      );
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.missingConnection));
      expect(result, hasCode(ComparisonValidationErrorCode.missingWhatChanged));
    });
  });

  group('ComparisonOutputValidator dates', () {
    test('accepts valid chronological dates', () {
      final result = validator.validate(
        validOutput(pastDate: '2025-12-31', currentDate: '2026-01-01'),
      );
      expect(result.isValid, isTrue);
    });

    for (final value in ['not-a-date', '24/07/2026', '2026-13-01']) {
      test('rejects malformed date $value', () {
        final result = validator.validate(validOutput(pastDate: value));
        expect(result.isValid, isFalse);
        expect(
          result,
          hasCode(ComparisonValidationErrorCode.malformedPastDate),
        );
      });
    }

    test('rejects impossible calendar date', () {
      final result = validator.validate(validOutput(pastDate: '2026-02-30'));
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.malformedPastDate));
    });

    test('rejects evidence dates in reverse order', () {
      final result = validator.validate(
        validOutput(pastDate: '2026-02-02', currentDate: '2026-02-01'),
      );
      expect(result.isValid, isFalse);
      expect(
        result,
        hasCode(ComparisonValidationErrorCode.evidenceDatesOutOfOrder),
      );
    });

    test('rejects historical context newer than the current moment', () {
      final result = validator.validate(
        validOutput(),
        currentMoment: _moment('current', DateTime.utc(2026, 1, 1)),
        historicalMoments: [_moment('future', DateTime.utc(2026, 1, 2))],
      );
      expect(result.isValid, isFalse);
      expect(
        result,
        hasCode(ComparisonValidationErrorCode.historicalDatesOutOfOrder),
      );
    });
  });

  group('ComparisonOutputValidator recovery', () {
    test('normalizes whitespace and surrounding markdown', () {
      final result = validator.validate(
        validOutput(
          sourceLabel: '**Clear repeat**',
          connection: '  **A   repeated response.**  ',
          past: '  `Past   evidence.` ',
          current: ' Current    evidence. ',
          whatChanged: '\n\nChange   remained.\n\n\n',
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.severity, ComparisonValidationSeverity.warning);
      expect(result, hasCode(ComparisonValidationErrorCode.textSanitized));
      expect(result.sanitizedOutput!.connectionText, 'A repeated response.');
      expect(result.sanitizedOutput!.pastQuote, 'Past evidence.');
      expect(result.sanitizedOutput!.whatChangedText, 'Change remained.');
    });

    test('safely trims excessive summaries and evidence', () {
      final result = validator.validate(
        validOutput(
          connection: _repeat('c', 201),
          past: _repeat('p', 101),
          current: _repeat('n', 101),
          whatChanged: _repeat('w', 201),
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.severity, ComparisonValidationSeverity.warning);
      expect(result, hasCode(ComparisonValidationErrorCode.summaryTrimmed));
      expect(result, hasCode(ComparisonValidationErrorCode.evidenceTrimmed));
      expect(result.sanitizedOutput!.connectionText.runes.length, 200);
      expect(result.sanitizedOutput!.pastQuote.runes.length, 100);
    });
  });

  group('ComparisonOutputValidator parser pipeline', () {
    const parser = ComparisonOutputParser();

    test('parser valid and validator valid', () {
      final result = validator.validate(
        parser.parse(_rawOutput(label: 'Clear repeat')),
      );
      expect(result.isValid, isTrue);
      expect(result.validationErrors, isEmpty);
    });

    test('parser valid and validator warning', () {
      final result = validator.validate(
        parser.parse(
          _rawOutput(label: 'Clear repeat', past: _repeat('p', 101)),
        ),
      );
      expect(result.isValid, isTrue);
      expect(result.severity, ComparisonValidationSeverity.warning);
    });

    test('parser valid and validator fatal', () {
      final result = validator.validate(
        parser.parse(_rawOutput(label: 'Unknown label')),
      );
      expect(result.isValid, isFalse);
      expect(result, hasCode(ComparisonValidationErrorCode.unknownLabel));
    });
  });
}

ArchiveMomentRecord _moment(String id, DateTime createdAt) =>
    ArchiveMomentRecord(id: id, createdAt: createdAt, savedWords: id);

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

String _rawOutput({required String label, String past = 'Past evidence.'}) =>
    '''
Label: $label
Connection: A cautious connection.
Evidence:
- Past: "$past"
- Present: "Current evidence."
What Changed: A precise change.
''';
