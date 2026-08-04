import '../models/archive_moment_record.dart';

class ParsedComparisonOutput {
  final PatternState state;
  final String connectionText;
  final String pastQuote;
  final String currentQuote;
  final String whatChangedText;

  const ParsedComparisonOutput({
    required this.state,
    required this.connectionText,
    required this.pastQuote,
    required this.currentQuote,
    required this.whatChangedText,
    this.sourceLabel,
    this.confidence,
    this.confidenceSource,
    this.pastEvidenceDate,
    this.currentEvidenceDate,
    this.sourceHadConnection,
    this.sourceHadWhatChanged,
    this.sourceHadEvidence,
  });

  /// Optional source metadata retained for post-parse validation.
  ///
  /// The production prompt does not currently require numeric confidence or
  /// dates, but retaining them when a model supplies them lets the validator
  /// reject corrupted or contradictory metadata.
  final String? sourceLabel;
  final double? confidence;
  final String? confidenceSource;
  final String? pastEvidenceDate;
  final String? currentEvidenceDate;
  final bool? sourceHadConnection;
  final bool? sourceHadWhatChanged;
  final bool? sourceHadEvidence;
}

class ComparisonOutputParser {
  const ComparisonOutputParser();

  static const String _defaultConnection = 'A repeating thread may be forming.';
  static const String _defaultWhatChanged =
      'ArchiveMe needs more moments to be sure.';

  static final RegExp _fieldHeaderPattern = RegExp(
    r'^(?:[-+*]|\d+[.)])?\s*[*_~`]{0,3}'
    r'(label|confidence|connection|evidence|past\s+date|'
    r'(?:present|current)\s+date|what\s+changed)'
    r'[*_~`]{0,3}\s*(?::|[-–—])?\s*[*_~`]{0,3}(.*)$',
    caseSensitive: false,
  );

  static final RegExp _evidencePattern = RegExp(
    r'^(?:[-+*]|\d+[.)])?\s*[*_~`]{0,3}'
    r'(past|present|current)'
    r'[*_~`]{0,3}\s*(?::|[-–—])?\s*[*_~`]{0,3}(.*)$',
    caseSensitive: false,
  );

  static final RegExp _unexpectedHeadingPattern = RegExp(
    r'^(?:[A-Z][\p{L}\d_-]*\s*){1,5}:\s*.*$',
    unicode: true,
  );

  /// Parses the strict LLM markdown block into structured fields.
  ///
  /// Recovery assumptions:
  /// - Known headings are case-insensitive and may omit punctuation or include
  ///   common Markdown/list decoration.
  /// - A recognized, non-empty duplicate replaces the earlier value. Empty or
  ///   invalid duplicates never erase information already recovered.
  /// - Unknown headings end the active section so unrelated model commentary
  ///   cannot be appended to a valid field.
  /// - Missing labels, connection text, or change analysis use conservative
  ///   defaults. Evidence quotes remain empty when they cannot be recovered so
  ///   callers can reject an incomplete remote response and use local analysis.
  ParsedComparisonOutput parse(String rawOutput) {
    PatternState state = PatternState.notEnoughEvidence;
    String connection = '';
    String past = '';
    String current = '';
    String whatChanged = '';
    String? sourceLabel;
    double? confidence;
    String? confidenceSource;
    String? pastEvidenceDate;
    String? currentEvidenceDate;
    var sourceHadConnection = false;
    var sourceHadWhatChanged = false;
    var sourceHadEvidence = false;

    _ComparisonSection currentSection = _ComparisonSection.none;

    for (final rawLine in rawOutput.split(RegExp(r'\r\n?|\n'))) {
      final normalized = _normalizeLine(rawLine);
      if (normalized == null) continue;
      final line = normalized.text;

      final headerMatch = _fieldHeaderPattern.firstMatch(line);
      if (headerMatch != null) {
        final field = headerMatch
            .group(1)!
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        final value = _cleanValue(headerMatch.group(2) ?? '');

        switch (field) {
          case 'label':
            if (value.isNotEmpty) sourceLabel = value;
            final parsedState = _tryMapLabelToState(value);
            if (parsedState != null) state = parsedState;
            currentSection = _ComparisonSection.none;
          case 'confidence':
            if (value.isNotEmpty) confidenceSource = value;
            confidence = value.isEmpty ? null : double.tryParse(value);
            currentSection = _ComparisonSection.none;
          case 'connection':
            if (value.isNotEmpty) {
              connection = value;
              sourceHadConnection = true;
            }
            currentSection = _ComparisonSection.connection;
          case 'evidence':
            sourceHadEvidence = true;
            currentSection = _ComparisonSection.evidence;
          case 'past date':
            if (value.isNotEmpty) pastEvidenceDate = value;
            currentSection = _ComparisonSection.none;
          case 'present date':
          case 'current date':
            if (value.isNotEmpty) currentEvidenceDate = value;
            currentSection = _ComparisonSection.none;
          case 'what changed':
            if (value.isNotEmpty) {
              whatChanged = value;
              sourceHadWhatChanged = true;
            }
            currentSection = _ComparisonSection.whatChanged;
        }
        continue;
      }

      final evidenceMatch = _evidencePattern.firstMatch(line);
      if (evidenceMatch != null) {
        final evidenceKind = evidenceMatch.group(1)!.toLowerCase();
        final value = _cleanEvidenceValue(evidenceMatch.group(2) ?? '');
        if (evidenceKind == 'past') {
          if (value.isNotEmpty) {
            past = value;
            sourceHadEvidence = true;
          }
          currentSection = _ComparisonSection.pastEvidence;
        } else {
          if (value.isNotEmpty) {
            current = value;
            sourceHadEvidence = true;
          }
          currentSection = _ComparisonSection.currentEvidence;
        }
        continue;
      }

      if (normalized.wasMarkdownHeading ||
          _unexpectedHeadingPattern.hasMatch(line)) {
        currentSection = _ComparisonSection.none;
        continue;
      }

      final continuation = _cleanValue(line);
      if (continuation.isEmpty) continue;
      switch (currentSection) {
        case _ComparisonSection.connection:
          connection = _append(connection, continuation);
          sourceHadConnection = true;
        case _ComparisonSection.whatChanged:
          whatChanged = _append(whatChanged, continuation);
          sourceHadWhatChanged = true;
        case _ComparisonSection.pastEvidence:
          past = _append(past, _cleanEvidenceValue(continuation));
          sourceHadEvidence = true;
        case _ComparisonSection.currentEvidence:
          current = _append(current, _cleanEvidenceValue(continuation));
          sourceHadEvidence = true;
        case _ComparisonSection.none:
        case _ComparisonSection.evidence:
          break;
      }
    }

    return ParsedComparisonOutput(
      state: state,
      connectionText: connection.isEmpty ? _defaultConnection : connection,
      pastQuote: past,
      currentQuote: current,
      whatChangedText: whatChanged.isEmpty
          ? _defaultWhatChanged
          : whatChanged.trim(),
      sourceLabel: sourceLabel,
      confidence: confidence,
      confidenceSource: confidenceSource,
      pastEvidenceDate: pastEvidenceDate,
      currentEvidenceDate: currentEvidenceDate,
      sourceHadConnection: sourceHadConnection,
      sourceHadWhatChanged: sourceHadWhatChanged,
      sourceHadEvidence: sourceHadEvidence,
    );
  }

  static ({String text, bool wasMarkdownHeading})? _normalizeLine(
    String rawLine,
  ) {
    var line = rawLine.trim();
    if (line.isEmpty ||
        line.startsWith('```') ||
        line.startsWith('~~~') ||
        RegExp(r'^([-*_])\1{2,}$').hasMatch(line)) {
      return null;
    }

    var wasMarkdownHeading = false;
    final headingMatch = RegExp(r'^#{1,6}\s*(.*)$').firstMatch(line);
    if (headingMatch != null) {
      wasMarkdownHeading = true;
      line = headingMatch.group(1)!.trim();
    }
    line = line.replaceFirst(RegExp(r'^>\s*'), '').trim();
    if (line.isEmpty) return null;
    return (text: line, wasMarkdownHeading: wasMarkdownHeading);
  }

  static String _cleanEvidenceValue(String value) {
    var cleaned = _cleanValue(value);
    if (cleaned.startsWith('"') ||
        cleaned.startsWith("'") ||
        cleaned.startsWith('“') ||
        cleaned.startsWith('‘')) {
      cleaned = cleaned.substring(1).trimLeft();
    }
    if (cleaned.endsWith('"') ||
        cleaned.endsWith("'") ||
        cleaned.endsWith('”') ||
        cleaned.endsWith('’')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trimRight();
    }
    return cleaned;
  }

  static String _cleanValue(String value) {
    var cleaned = value.trim().replaceFirst(RegExp(r'^(?::|[-–—])\s*'), '');
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
    cleaned = cleaned
        .replaceFirst(RegExp(r'^[*_~`]{1,3}'), '')
        .replaceFirst(RegExp(r'[*_~`]{1,3}$'), '')
        .trim();
    return cleaned;
  }

  static String _append(String existing, String continuation) {
    if (continuation.isEmpty) return existing;
    return existing.isEmpty ? continuation : '$existing $continuation';
  }

  static PatternState? _tryMapLabelToState(String label) {
    final cleaned = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    switch (cleaned) {
      case 'early signal':
        return PatternState.earlySignal;
      case 'possible repeat':
        return PatternState.possibleRepeat;
      case 'clear repeat':
        return PatternState.clearRepeat;
      case 'still current':
        return PatternState.stillCurrent;
      case 'fading':
        return PatternState.fading;
      case 'changed':
        return PatternState.changed;
      case 'softened':
        return PatternState.softened;
      case 'corrected':
        return PatternState.corrected;
      case 'not enough evidence':
        return PatternState.notEnoughEvidence;
      default:
        return null;
    }
  }
}

enum _ComparisonSection {
  none,
  connection,
  evidence,
  pastEvidence,
  currentEvidence,
  whatChanged,
}
