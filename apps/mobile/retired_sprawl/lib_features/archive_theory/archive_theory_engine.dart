import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_belief_visibility.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_strengthening.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the archive's current theory using the Analyst confidence engine.
class ArchiveTheoryEngine {
  const ArchiveTheoryEngine({
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
  });

  static const int confidentThreshold = 60;

  final ArchiveAnalystConfidenceEngine confidenceEngine;

  /// Returns null when [statement] is empty or a gathering-evidence placeholder.
  ArchiveCurrentTheory? build({
    required List<JournalEntry> entries,
    required String? statement,
    int maxContradictionScore = 0,
    DateTime? lastUpdated,
    Set<String> contradictionEntryIds = const {},
  }) {
    final text = statement?.trim() ?? '';
    if (text.isEmpty || _isPlaceholder(text)) return null;

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty) return null;

    final split = confidenceEngine.splitEntries(
      beliefText: text,
      eligible: eligible,
      contradictionEntryIds: contradictionEntryIds,
    );

    final confidence = confidenceEngine.score(
      supportingCount: split.supporting.length,
      counterCount: split.counter.length,
      recencyRatio: split.recencyRatio,
      consistencyRatio: split.consistencyRatio,
      maxContradictionScore: maxContradictionScore,
      stale: split.stale,
    );

    final strengthening = ArchiveTheoryStrengthening.fromEvidence(
      split: split,
      confidencePercent: confidence,
      maxContradictionScore: maxContradictionScore,
    );

    final updated =
        lastUpdated ??
        (split.supporting.isNotEmpty
            ? split.supporting.last.createdAt
            : eligible.last.createdAt);

    final theory = ArchiveCurrentTheory(
      statement: text,
      confidencePercent: confidence,
      evidenceCount: split.supporting.length,
      counterEvidenceCount: split.counter.length,
      lastUpdated: updated,
      isConfident: confidence >= confidentThreshold,
      missingEvidenceMessage: strengthening.missingEvidenceMessage,
      strengthenEvidenceLines: strengthening.strengthenEvidenceLines,
    );

    if (!ArchiveBeliefVisibility.isVisibleTheory(theory)) return null;
    return theory;
  }

  bool _isPlaceholder(String text) {
    final lower = text.toLowerCase();
    return lower.contains('still gathering evidence') ||
        lower.contains('working belief is forming');
  }
}