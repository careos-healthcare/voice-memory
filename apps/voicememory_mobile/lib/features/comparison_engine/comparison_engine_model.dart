import 'comparison_engine_prompt.dart';

/// Exact confidence labels for comparison output.
enum ComparisonConfidenceLabel {
  earlySignal('Early signal'),
  possibleRepeat('Possible repeat'),
  clearRepeat('Clear repeat'),
  stillCurrent('Still current'),
  fading('Fading'),
  changed('Changed'),
  softened('Softened'),
  corrected('Corrected'),
  notEnoughEvidence('Not enough evidence');

  const ComparisonConfidenceLabel(this.label);

  final String label;

  static ComparisonConfidenceLabel? parse(String raw) {
    final trimmed = raw.trim();
    for (final value in ComparisonConfidenceLabel.values) {
      if (value.label == trimmed) return value;
    }
    return null;
  }
}

/// Structured comparison output — maps to the comparison engine system prompt.
class ComparisonEngineOutput {
  const ComparisonEngineOutput({
    required this.confidenceLabel,
    required this.whatAppearsRepeated,
    required this.connectedMomentDayTime,
    this.connectedEntryId,
    this.whatChanged,
    this.thinEvidencePhrase,
  });

  final ComparisonConfidenceLabel confidenceLabel;
  final String whatAppearsRepeated;
  final String connectedMomentDayTime;
  final String? connectedEntryId;
  final String? whatChanged;
  final String? thinEvidencePhrase;

  bool get hasThinEvidence =>
      thinEvidencePhrase != null && thinEvidencePhrase!.trim().isNotEmpty;

  /// Prompt-ordered summary for display or export.
  String formatStructuredSummary() {
    final lines = <String>[
      'Confidence: ${confidenceLabel.label}',
      'What appears to have repeated: $whatAppearsRepeated',
      'Connects to: $connectedMomentDayTime',
    ];
    final changed = whatChanged?.trim();
    if (changed != null && changed.isNotEmpty) {
      lines.add('What changed: $changed');
    }
    final caution = thinEvidencePhrase?.trim();
    if (caution != null && caution.isNotEmpty) {
      lines.add(caution);
    }
    return lines.join('\n');
  }

  /// Thread + change body used by Archive tab state 4.
  String formatArchiveThreadBody() {
    final thread = whatAppearsRepeated.trim();
    final change = whatChanged?.trim();
    final changeLine = (change != null && change.isNotEmpty)
        ? change
        : 'ArchiveMe is still comparing your saved words.';
    final buffer = StringBuffer(
      "Something came back. ArchiveMe found a pattern across your saved moments. "
      "This may connect to: '$thread'. What changed: $changeLine.",
    );
    final caution = thinEvidencePhrase?.trim();
    if (caution != null && caution.isNotEmpty) {
      buffer.write(' $caution');
    }
    return buffer.toString();
  }
}

class ComparisonEngineResult {
  const ComparisonEngineResult({
    required this.hasComparison,
    required this.isRelated,
    this.output,
  });

  final bool hasComparison;
  final bool isRelated;
  final ComparisonEngineOutput? output;

  static const insufficient = ComparisonEngineResult(
    hasComparison: false,
    isRelated: false,
  );

  static const unrelated = ComparisonEngineResult(
    hasComparison: true,
    isRelated: false,
  );
}
