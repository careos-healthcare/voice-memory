import '../../../models/journal_entry.dart';
import '../../archive_evidence/archive_evidence.dart';
import '../../contradiction_detection/contradiction_detection_service.dart';
import '../../contradiction_detection/statement_analysis.dart';
import '../insight_evidence.dart';
import '../insight_quality.dart';
import '../insight_text_signals.dart';
import 'contradiction_models.dart';

/// Detects desire vs action tension from real reflection text (min 3 cites).
class ContradictionInsightEngine {
  const ContradictionInsightEngine({
    this.minSupportingReferences = InsightQualityRules.minEvidenceCount,
  });

  final int minSupportingReferences;

  List<ContradictionInsight> build({
    required List<JournalEntry> entries,
    String? currentBelief,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minSupportingReferences) return const [];

    final out = <ContradictionInsight>[];
    out.addAll(_desireVsAction(eligible));
    out.addAll(_statementContradictions(eligible, currentBelief));

    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return out;
  }

  List<ContradictionInsight> _desireVsAction(List<JournalEntry> entries) {
    final desireLines = <InsightEvidenceLine>[];
    final actionLines = <InsightEvidenceLine>[];

    for (final e in entries) {
      for (final text in archiveStatementTexts(e)) {
        final lower = text.toLowerCase();
        if (_hits(lower, InsightTextSignals.desireMarkers)) {
          desireLines.add(
            InsightEvidenceLine(
              entryId: e.id,
              quote: text,
              recordedAt: e.createdAt,
              label: 'Stated desire',
            ),
          );
        }
        if (_hits(lower, InsightTextSignals.responsibilityMarkers)) {
          actionLines.add(
            InsightEvidenceLine(
              entryId: e.id,
              quote: text,
              recordedAt: e.createdAt,
              label: 'Observed action',
            ),
          );
        }
      }
    }

    if (desireLines.length < 2 ||
        actionLines.length < minSupportingReferences) {
      return const [];
    }

    final ids = {
      ...desireLines.map((l) => l.entryId),
      ...actionLines.map((l) => l.entryId),
    };
    final dates = [
      ...desireLines.map((l) => l.recordedAt),
      ...actionLines.map((l) => l.recordedAt),
    ]..sort();

    final summary =
        'You frequently say you want freedom, but your saved words show repeated '
        'choices that increase responsibility.';

    return [
      ContradictionInsight(
        id: 'ctr-desire-action',
        summary: summary,
        confidence: (58 + desireLines.length * 4 + actionLines.length * 3)
            .clamp(55, 92),
        evidenceCount: ids.length,
        supportingReflectionIds: ids.toList(),
        statedDesire: 'more freedom / space / balance',
        statedAction: 'taking on responsibility',
        recurringPattern: 'freedom language vs responsibility choices',
        evidence: [
          ContradictionEvidence(
            role: 'stated_desire',
            lines: desireLines.take(4).toList(),
          ),
          ContradictionEvidence(
            role: 'stated_action',
            lines: actionLines.take(4).toList(),
          ),
        ],
        firstSeen: dates.first,
        lastSeen: dates.last,
      ),
    ];
  }

  List<ContradictionInsight> _statementContradictions(
    List<JournalEntry> entries,
    String? belief,
  ) {
    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    final byId = {for (final e in entries) e.id: e};
    final insights = <ContradictionInsight>[];

    for (final r in result.reports) {
      final lines = [
        InsightEvidenceLine(
          entryId: r.originalEntryId,
          quote: r.originalStatement,
          recordedAt: byId[r.originalEntryId]?.createdAt ?? DateTime.now(),
          label: 'Earlier',
        ),
        InsightEvidenceLine(
          entryId: r.conflictingEntryId,
          quote: r.conflictingStatement,
          recordedAt: byId[r.conflictingEntryId]?.createdAt ?? DateTime.now(),
          label: 'Later',
        ),
      ];
      if (lines.length < 2) continue;

      insights.add(
        ContradictionInsight(
          id: r.id,
          summary:
              'Two moments on the same topic pull in different directions.',
          confidence: r.confidenceScore,
          evidenceCount: 2,
          supportingReflectionIds: [r.originalEntryId, r.conflictingEntryId],
          evidence: [
            ContradictionEvidence(role: 'stated_pattern', lines: lines),
          ],
          firstSeen: lines.first.recordedAt,
          lastSeen: lines.last.recordedAt,
          recurringPattern: r.sharedThemes.join(', '),
        ),
      );
    }
    return insights.where((i) => i.evidenceCount >= 2).toList();
  }

  bool _hits(String lower, List<String> markers) {
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }
}
