import '../ai_engines/models/ai_explainability.dart';

/// Archive's current working theory (evidence-backed, no AI at read time).
class ArchiveCurrentTheory {
  const ArchiveCurrentTheory({
    required this.statement,
    required this.confidencePercent,
    required this.evidenceCount,
    required this.counterEvidenceCount,
    required this.lastUpdated,
    required this.isConfident,
    required this.missingEvidenceMessage,
    required this.strengthenEvidenceLines,
  });

  final String statement;
  final int confidencePercent;
  final int evidenceCount;
  final int counterEvidenceCount;
  final DateTime? lastUpdated;

  /// True when [confidencePercent] >= [ArchiveTheoryEngine.confidentThreshold].
  final bool isConfident;
  final String missingEvidenceMessage;
  final List<String> strengthenEvidenceLines;

  AiExplainability get explainability => AiExplainability(
    confidence: confidencePercent.clamp(0, 100),
    evidence: strengthenEvidenceLines.isEmpty
        ? [AiEvidenceSource(sourceId: 'archive_theory', excerpt: statement)]
        : strengthenEvidenceLines
              .asMap()
              .entries
              .map(
                (item) => AiEvidenceSource(
                  sourceId: 'archive_theory_${item.key}',
                  excerpt: item.value,
                ),
              )
              .toList(),
    reasoning: [
      '$evidenceCount recordings support this working theory.',
      '$counterEvidenceCount recordings provide counter-evidence.',
      'The confidence score balances support against counter-evidence.',
    ],
    alternativeExplanation:
        'The same evidence may reflect a short-term situation instead of an '
        'enduring pattern.',
    uncertainty: missingEvidenceMessage.trim().isEmpty
        ? 'Unrecorded context or future entries may change this working theory.'
        : missingEvidenceMessage,
  );
}
