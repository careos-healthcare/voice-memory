import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceProofCalculator', () {
    test('computes frequency and timespan for multiple ledger citations', () {
      final base = DateTime.utc(2026);
      final artifact = EvidenceProofCalculator.fromInsight(
        Insight(
          id: 'insight-1',
          insightText: 'Work pressure keeps returning on Sunday nights',
          kind: ArchiveInsightKind.theme,
          confidenceBand: PatternMatchConfidenceBand.solid,
          citedEntries: [
            CitedEntry(
              entryId: 'e1',
              rawText: 'Sunday dread again before the week starts',
              createdAt: base,
            ),
            CitedEntry(
              entryId: 'e2',
              rawText: 'Could not sleep thinking about Monday meetings',
              createdAt: base.add(const Duration(days: 14)),
            ),
            CitedEntry(
              entryId: 'e3',
              rawText: 'Same Sunday tension as last month',
              createdAt: base.add(const Duration(days: 28)),
            ),
            CitedEntry(
              entryId: 'e4',
              rawText: 'Weekend ends with the same knot in my stomach',
              createdAt: base.add(const Duration(days: 42)),
            ),
          ],
        ),
      );

      expect(artifact.stats.totalFrequency, 4);
      expect(artifact.stats.spanDays, 42);
      expect(artifact.stats.frequencyBadgeLabel, 'Detected 4× in 42 days');
      expect(artifact.stats.timespanLabel, '4 times over 6 weeks');
      expect(artifact.stats.occurrenceDensityPerWeek, closeTo(0.67, 0.01));
      expect(artifact.citations.first.entryId, 'e1');
      expect(artifact.citations.last.entryId, 'e4');
      expect(artifact.citations.first.quote, contains('Sunday dread'));
    });

    test('handles single citation without span math', () {
      final artifact = EvidenceProofCalculator.fromInsight(
        Insight(
          id: 'insight-2',
          insightText: 'One-off note',
          kind: ArchiveInsightKind.theme,
          confidenceBand: PatternMatchConfidenceBand.weak,
          citedEntries: [
            CitedEntry(
              entryId: 'solo',
              rawText: 'Only one mention so far',
              createdAt: DateTime.utc(2026, 2),
            ),
          ],
        ),
      );

      expect(artifact.stats.totalFrequency, 1);
      expect(artifact.stats.timespanLabel, '1 time');
      expect(artifact.stats.frequencyBadgeLabel, 'Detected 1×');
      expect(artifact.stats.occurrenceDensityPerWeek, 1);
    });

    test('maps archive confidence percent to confidence band', () {
      expect(
        EvidenceProofCalculator.bandFromConfidencePercent(80),
        PatternMatchConfidenceBand.strong,
      );
      expect(
        EvidenceProofCalculator.bandFromConfidencePercent(60),
        PatternMatchConfidenceBand.solid,
      );
      expect(
        EvidenceProofCalculator.bandFromConfidencePercent(40),
        PatternMatchConfidenceBand.emerging,
      );
      expect(
        EvidenceProofCalculator.bandFromConfidencePercent(10),
        PatternMatchConfidenceBand.weak,
      );
    });

    test('returns empty stats when no citations exist', () {
      final artifact = EvidenceProofCalculator.fromInsight(
        const Insight(
          id: 'empty',
          insightText: 'No evidence yet',
          kind: ArchiveInsightKind.theme,
          confidenceBand: PatternMatchConfidenceBand.weak,
          citedEntries: [],
        ),
      );

      expect(artifact.stats.totalFrequency, 0);
      expect(artifact.stats.frequencyBadgeLabel, 'No detections');
      expect(artifact.hasCitations, isFalse);
    });
  });
}