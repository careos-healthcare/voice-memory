import 'package:archiveme_mobile/features/archive_theory/archive_theory_engine.dart' show ArchiveTheoryEngine;

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
}