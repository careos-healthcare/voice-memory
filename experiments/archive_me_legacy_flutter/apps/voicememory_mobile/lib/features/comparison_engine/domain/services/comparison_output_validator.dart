import '../../comparison_engine_prompt.dart';
import '../models/archive_moment_record.dart';
import 'comparison_output_parser.dart';

enum ComparisonValidationSeverity { warning, fatal }

enum ComparisonValidationErrorCode {
  missingLabel,
  unknownLabel,
  contradictoryLabel,
  missingConnection,
  missingWhatChanged,
  missingPastEvidence,
  missingCurrentEvidence,
  malformedConfidence,
  nonFiniteConfidence,
  confidenceOutOfRange,
  malformedPastDate,
  malformedCurrentDate,
  evidenceDatesOutOfOrder,
  historicalDatesOutOfOrder,
  textSanitized,
  evidenceTrimmed,
  summaryTrimmed,
  unsafeSummary,
}

final class ComparisonValidationError {
  const ComparisonValidationError({
    required this.code,
    required this.severity,
    required this.field,
  });

  final ComparisonValidationErrorCode code;
  final ComparisonValidationSeverity severity;
  final String field;
}

final class ComparisonOutputValidationResult {
  ComparisonOutputValidationResult._({
    required List<ComparisonValidationError> validationErrors,
    required this.sanitizedOutput,
  }) : validationErrors = List.unmodifiable(validationErrors);

  final List<ComparisonValidationError> validationErrors;
  final ParsedComparisonOutput? sanitizedOutput;

  bool get isValid => sanitizedOutput != null;

  ComparisonValidationSeverity? get severity {
    if (validationErrors.any(
      (error) => error.severity == ComparisonValidationSeverity.fatal,
    )) {
      return ComparisonValidationSeverity.fatal;
    }
    return validationErrors.isEmpty
        ? null
        : ComparisonValidationSeverity.warning;
  }
}

/// Pure validation boundary between parsed model output and presentation.
///
/// Numeric confidence and evidence dates are optional because they are not
/// part of the production comparison prompt. When supplied, they must be
/// valid. Confidence is never clamped: this project has no convention that
/// permits changing model certainty. Dates use strict ISO calendar validation
/// because `DateTime.parse` otherwise normalizes impossible dates.
final class ComparisonOutputValidator {
  const ComparisonOutputValidator({
    this.maxEvidenceCharacters = 4000,
    this.maxSummaryCharacters = 6000,
  }) : assert(maxEvidenceCharacters > 0),
       assert(maxSummaryCharacters > 0);

  final int maxEvidenceCharacters;
  final int maxSummaryCharacters;

  ComparisonOutputValidationResult validate(
    ParsedComparisonOutput output, {
    ArchiveMomentRecord? currentMoment,
    List<ArchiveMomentRecord> historicalMoments = const <ArchiveMomentRecord>[],
  }) {
    final errors = <ComparisonValidationError>[];

    final label = _sanitizeText(output.sourceLabel ?? '');
    final expectedState = _stateForLabel(label);
    if (label.isEmpty) {
      _fatal(errors, ComparisonValidationErrorCode.missingLabel, 'label');
    } else if (expectedState == null) {
      _fatal(errors, ComparisonValidationErrorCode.unknownLabel, 'label');
    } else if (expectedState != output.state) {
      _fatal(errors, ComparisonValidationErrorCode.contradictoryLabel, 'label');
    }

    var connection = _sanitizeText(output.connectionText);
    var pastQuote = _sanitizeText(output.pastQuote);
    var currentQuote = _sanitizeText(output.currentQuote);
    var whatChanged = _sanitizeText(output.whatChangedText);
    _recordSanitization(
      errors,
      original: output.connectionText,
      sanitized: connection,
      field: 'connection',
    );
    _recordSanitization(
      errors,
      original: output.pastQuote,
      sanitized: pastQuote,
      field: 'pastEvidence',
    );
    _recordSanitization(
      errors,
      original: output.currentQuote,
      sanitized: currentQuote,
      field: 'currentEvidence',
    );
    _recordSanitization(
      errors,
      original: output.whatChangedText,
      sanitized: whatChanged,
      field: 'whatChanged',
    );

    if (connection.isEmpty || output.sourceHadConnection == false) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.missingConnection,
        'connection',
      );
    }
    if (whatChanged.isEmpty || output.sourceHadWhatChanged == false) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.missingWhatChanged,
        'whatChanged',
      );
    }

    final evidenceRequired = output.state != PatternState.notEnoughEvidence;
    if (evidenceRequired && pastQuote.isEmpty) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.missingPastEvidence,
        'pastEvidence',
      );
    }
    if (evidenceRequired && currentQuote.isEmpty) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.missingCurrentEvidence,
        'currentEvidence',
      );
    }

    if (ComparisonEnginePrompt.violatesBannedPhrase(connection)) {
      _fatal(errors, ComparisonValidationErrorCode.unsafeSummary, 'connection');
    }
    if (ComparisonEnginePrompt.violatesBannedPhrase(whatChanged)) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.unsafeSummary,
        'whatChanged',
      );
    }

    connection = _trimToLimit(
      connection,
      maxSummaryCharacters,
      errors,
      ComparisonValidationErrorCode.summaryTrimmed,
      'connection',
    );
    whatChanged = _trimToLimit(
      whatChanged,
      maxSummaryCharacters,
      errors,
      ComparisonValidationErrorCode.summaryTrimmed,
      'whatChanged',
    );
    pastQuote = _trimToLimit(
      pastQuote,
      maxEvidenceCharacters,
      errors,
      ComparisonValidationErrorCode.evidenceTrimmed,
      'pastEvidence',
    );
    currentQuote = _trimToLimit(
      currentQuote,
      maxEvidenceCharacters,
      errors,
      ComparisonValidationErrorCode.evidenceTrimmed,
      'currentEvidence',
    );

    _validateConfidence(output, errors);
    _validateDates(
      output,
      currentMoment: currentMoment,
      historicalMoments: historicalMoments,
      errors: errors,
    );

    final hasFatal = errors.any(
      (error) => error.severity == ComparisonValidationSeverity.fatal,
    );
    return ComparisonOutputValidationResult._(
      validationErrors: errors,
      sanitizedOutput: hasFatal
          ? null
          : ParsedComparisonOutput(
              state: output.state,
              connectionText: connection,
              pastQuote: pastQuote,
              currentQuote: currentQuote,
              whatChangedText: whatChanged,
              sourceLabel: canonicalLabelFor(output.state),
              confidence: output.confidence,
              confidenceSource: output.confidenceSource,
              pastEvidenceDate: _sanitizeNullable(output.pastEvidenceDate),
              currentEvidenceDate: _sanitizeNullable(
                output.currentEvidenceDate,
              ),
              sourceHadConnection: true,
              sourceHadWhatChanged: true,
              sourceHadEvidence: output.sourceHadEvidence,
            ),
    );
  }

  static void _validateConfidence(
    ParsedComparisonOutput output,
    List<ComparisonValidationError> errors,
  ) {
    if (output.confidenceSource != null && output.confidence == null) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.malformedConfidence,
        'confidence',
      );
      return;
    }
    final confidence = output.confidence;
    if (confidence == null) return;
    if (!confidence.isFinite) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.nonFiniteConfidence,
        'confidence',
      );
    } else if (confidence < 0 || confidence > 1) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.confidenceOutOfRange,
        'confidence',
      );
    }
  }

  static void _validateDates(
    ParsedComparisonOutput output, {
    required ArchiveMomentRecord? currentMoment,
    required List<ArchiveMomentRecord> historicalMoments,
    required List<ComparisonValidationError> errors,
  }) {
    final pastDate = _parseStrictDate(output.pastEvidenceDate);
    final currentDate = _parseStrictDate(output.currentEvidenceDate);
    if (output.pastEvidenceDate != null && pastDate == null) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.malformedPastDate,
        'pastEvidenceDate',
      );
    }
    if (output.currentEvidenceDate != null && currentDate == null) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.malformedCurrentDate,
        'currentEvidenceDate',
      );
    }
    if (pastDate != null &&
        currentDate != null &&
        pastDate.isAfter(currentDate)) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.evidenceDatesOutOfOrder,
        'evidenceDates',
      );
    }
    if (currentMoment != null &&
        historicalMoments.any(
          (moment) => moment.createdAt.isAfter(currentMoment.createdAt),
        )) {
      _fatal(
        errors,
        ComparisonValidationErrorCode.historicalDatesOutOfOrder,
        'historicalMoments',
      );
    }
  }

  static DateTime? _parseStrictDate(String? value) {
    if (value == null) return null;
    final cleaned = _sanitizeText(value);
    final calendar = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ].*)?$',
    ).firstMatch(cleaned);
    if (calendar == null) return null;
    final parsed = DateTime.tryParse(cleaned);
    if (parsed == null) return null;
    return parsed.year == int.parse(calendar.group(1)!) &&
            parsed.month == int.parse(calendar.group(2)!) &&
            parsed.day == int.parse(calendar.group(3)!)
        ? parsed
        : null;
  }

  static String _sanitizeText(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .trim()
        .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    var changed = true;
    while (changed && cleaned.length >= 2) {
      changed = false;
      for (final wrapper in const ['**', '__', '~~', '`', '*', '_']) {
        if (cleaned.startsWith(wrapper) &&
            cleaned.endsWith(wrapper) &&
            cleaned.length > wrapper.length * 2) {
          cleaned = cleaned
              .substring(wrapper.length, cleaned.length - wrapper.length)
              .trim();
          changed = true;
          break;
        }
      }
    }
    return cleaned
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String? _sanitizeNullable(String? value) {
    if (value == null) return null;
    final cleaned = _sanitizeText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _trimToLimit(
    String value,
    int limit,
    List<ComparisonValidationError> errors,
    ComparisonValidationErrorCode code,
    String field,
  ) {
    final runes = value.runes;
    if (runes.length <= limit) return value;
    _warning(errors, code, field);
    return String.fromCharCodes(runes.take(limit)).trimRight();
  }

  static void _recordSanitization(
    List<ComparisonValidationError> errors, {
    required String original,
    required String sanitized,
    required String field,
  }) {
    if (original != sanitized) {
      _warning(errors, ComparisonValidationErrorCode.textSanitized, field);
    }
  }

  static PatternState? _stateForLabel(String label) {
    final normalized = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final state in PatternState.values) {
      if (canonicalLabelFor(state).toLowerCase() == normalized) return state;
    }
    return null;
  }

  static String canonicalLabelFor(PatternState state) {
    switch (state) {
      case PatternState.earlySignal:
        return 'Early signal';
      case PatternState.possibleRepeat:
        return 'Possible repeat';
      case PatternState.clearRepeat:
        return 'Clear repeat';
      case PatternState.stillCurrent:
        return 'Still current';
      case PatternState.fading:
        return 'Fading';
      case PatternState.changed:
        return 'Changed';
      case PatternState.softened:
        return 'Softened';
      case PatternState.corrected:
        return 'Corrected';
      case PatternState.notEnoughEvidence:
        return 'Not enough evidence';
    }
  }

  static void _warning(
    List<ComparisonValidationError> errors,
    ComparisonValidationErrorCode code,
    String field,
  ) {
    errors.add(
      ComparisonValidationError(
        code: code,
        severity: ComparisonValidationSeverity.warning,
        field: field,
      ),
    );
  }

  static void _fatal(
    List<ComparisonValidationError> errors,
    ComparisonValidationErrorCode code,
    String field,
  ) {
    errors.add(
      ComparisonValidationError(
        code: code,
        severity: ComparisonValidationSeverity.fatal,
        field: field,
      ),
    );
  }
}
