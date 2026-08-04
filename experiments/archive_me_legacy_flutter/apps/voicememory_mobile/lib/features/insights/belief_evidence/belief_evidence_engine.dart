import '../../../models/journal_entry.dart';
import '../../archive_evidence/archive_evidence.dart';
import '../../contradiction_detection/statement_analysis.dart';
import '../insight_evidence.dart';
import '../insight_quality.dart';
import 'belief_evidence_bundle.dart';

/// Builds evidence bundles — no belief without quotes and reflection ids.
class BeliefEvidenceEngine {
  const BeliefEvidenceEngine({
    this.minSupportingReferences = InsightQualityRules.minEvidenceCount,
  });

  final int minSupportingReferences;

  List<BeliefEvidenceBundle> build({
    required List<JournalEntry> entries,
    required List<({String statement, int confidence})> candidateBeliefs,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final bundles = <BeliefEvidenceBundle>[];

    for (var i = 0; i < candidateBeliefs.length; i++) {
      final c = candidateBeliefs[i];
      final bundle = _bundleForStatement(
        beliefId: 'belief-${c.statement.hashCode.abs()}',
        statement: c.statement,
        confidence: c.confidence,
        entries: eligible,
      );
      if (bundle != null && bundle.hasMinimumEvidence) {
        bundles.add(bundle);
      }
    }

    return bundles;
  }

  BeliefEvidenceBundle? _bundleForStatement({
    required String beliefId,
    required String statement,
    required int confidence,
    required List<JournalEntry> entries,
  }) {
    final needle = _keywords(statement);
    if (needle.isEmpty) return null;

    final evidence = <InsightEvidenceLine>[];
    for (final e in entries) {
      for (final text in archiveStatementTexts(e)) {
        final lower = text.toLowerCase();
        if (!_matches(lower, needle)) continue;
        evidence.add(
          InsightEvidenceLine(
            entryId: e.id,
            quote: text,
            recordedAt: e.createdAt,
          ),
        );
      }
    }

    if (evidence.length < minSupportingReferences) return null;

    final ids = evidence.map((e) => e.entryId).toSet().toList();
    final quotes = evidence.map((e) => e.quote).toList();

    return BeliefEvidenceBundle(
      beliefId: beliefId,
      statement: statement,
      confidence: confidence,
      supportingEvidence: evidence,
      supportingReflectionIds: ids,
      supportingQuotes: quotes,
      whyArchiveBelievesThis:
          'This wording appeared in ${ids.length} saved moments with similar themes.',
      archiveConclusion:
          'ArchiveMe connects these moments because the same pattern '
          'shows up across them — not because of a single emotional day.',
    );
  }

  Set<String> _keywords(String statement) {
    return statement
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 4)
        .toSet();
  }

  bool _matches(String lower, Set<String> needle) {
    var hits = 0;
    for (final n in needle) {
      if (lower.contains(n)) hits++;
    }
    return hits >= (needle.length >= 2 ? 2 : 1);
  }
}
