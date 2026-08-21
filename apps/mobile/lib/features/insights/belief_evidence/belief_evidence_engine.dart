import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/insights/belief_evidence/belief_evidence_bundle.dart';
import 'package:archiveme_mobile/features/insights/insight_evidence.dart';
import 'package:archiveme_mobile/features/insights/insight_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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
            quote: FactLedgerCitationService.resolve(
              entryId: e.id,
              fallback: text,
            ),
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
          'Based on these entries, this wording appeared in ${ids.length} reflections with similar themes.',
      archiveConclusion:
          'Your archive noticed the same pattern across these moments — '
          'not just one emotional day. You can correct or hide this.',
    );
  }

  Set<String> _keywords(String statement) {
    return statement
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
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