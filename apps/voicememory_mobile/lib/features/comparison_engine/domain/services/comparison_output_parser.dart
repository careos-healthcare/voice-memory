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
  });
}

class ComparisonOutputParser {
  const ComparisonOutputParser();

  static final RegExp _fieldHeaderPattern = RegExp(
    r'^(label|connection|evidence|what changed)\s*:?\s*(.*)$',
    caseSensitive: false,
  );

  static final RegExp _pastRegex = RegExp(
    r'^-\s*Past:?\s*"(.*)"\s*$',
    caseSensitive: false,
  );

  static final RegExp _presentRegex = RegExp(
    r'^-\s*Present:?\s*"(.*)"\s*$',
    caseSensitive: false,
  );

  /// Parses the strict LLM markdown block into structured fields.
  ParsedComparisonOutput parse(String rawOutput) {
    final lines = _sanitize(rawOutput).split('\n');

    PatternState state = PatternState.notEnoughEvidence;
    String connection = '';
    String past = '';
    String current = '';
    String whatChanged = '';

    String currentSection = '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == '---') continue;

      final headerMatch = _fieldHeaderPattern.firstMatch(trimmed);
      if (headerMatch != null) {
        final field = headerMatch.group(1)!.toLowerCase();
        final value = headerMatch.group(2)?.trim() ?? '';

        switch (field) {
          case 'label':
            state = _mapLabelToState(value);
            currentSection = '';
          case 'connection':
            connection = value;
            currentSection = '';
          case 'evidence':
            currentSection = 'evidence';
          case 'what changed':
            whatChanged = value;
            currentSection = 'whatChanged';
        }
        continue;
      }

      if (currentSection == 'evidence') {
        final pastMatch = _pastRegex.firstMatch(trimmed);
        if (pastMatch != null) {
          past = pastMatch.group(1) ?? '';
          continue;
        }
        final presentMatch = _presentRegex.firstMatch(trimmed);
        if (presentMatch != null) {
          current = presentMatch.group(1) ?? '';
        }
      } else if (currentSection == 'whatChanged') {
        if (whatChanged.isEmpty) {
          whatChanged = trimmed;
        } else {
          whatChanged += ' $trimmed';
        }
      }
    }

    return ParsedComparisonOutput(
      state: state,
      connectionText:
          connection.isEmpty ? 'A repeating thread may be forming.' : connection,
      pastQuote: past,
      currentQuote: current,
      whatChangedText: whatChanged.isEmpty
          ? 'ArchiveMe needs more moments to be sure.'
          : whatChanged.trim(),
    );
  }

  String _sanitize(String rawOutput) {
    final cleaned = <String>[];
    for (final line in rawOutput.split('\n')) {
      var trimmed = line.trim();
      if (trimmed.startsWith('```')) continue;
      trimmed = trimmed.replaceAll('`', '');
      cleaned.add(trimmed);
    }
    return cleaned.join('\n');
  }

  PatternState _mapLabelToState(String label) {
    final cleaned = label.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
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
      default:
        return PatternState.notEnoughEvidence;
    }
  }
}
