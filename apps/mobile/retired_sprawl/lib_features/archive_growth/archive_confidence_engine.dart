import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_maturity.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

class ArchiveConfidenceView {
  const ArchiveConfidenceView({
    required this.score,
    required this.explanation,
    required this.maturity,
  });

  final int score;
  final String explanation;
  final ArchiveGrowthMaturity maturity;
}

/// Trust-oriented archive confidence (0–100) — not gamified.
abstract class ArchiveConfidenceEngine {
  ArchiveConfidenceEngine._();

  static ArchiveConfidenceView build({
    required List<JournalEntry> entries,
    ArchiveV1View? archiveV1,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final count = eligible.length;
    final theory = archiveV1?.theory;
    final theoryConf = theory?.confidencePercent ?? 0;
    final evidenceCount = theory?.evidenceCount ?? 0;
    final contradictions = archiveV1?.contradictions.length ?? 0;

    final recordingSignal = (count / 50 * 40).clamp(0, 40);
    final theorySignal = (theoryConf / 100 * 30).clamp(0, 30);
    final evidenceSignal = (evidenceCount / 15 * 20).clamp(0, 20);
    final contradictionSignal = contradictions > 0
        ? (contradictions.clamp(0, 4) * 2.5).clamp(0, 10)
        : 0;

    final score =
        (recordingSignal + theorySignal + evidenceSignal + contradictionSignal)
            .round()
            .clamp(0, 100);

    final explanation = _explanation(
      recordingCount: count,
      theoryConfidence: theoryConf,
      evidenceCount: evidenceCount,
      score: score,
    );

    return ArchiveConfidenceView(
      score: score,
      explanation: explanation,
      maturity: ArchiveGrowthMaturity.fromRecordingCount(count),
    );
  }

  static String _explanation({
    required int recordingCount,
    required int theoryConfidence,
    required int evidenceCount,
    required int score,
  }) {
    if (recordingCount < 5) {
      return 'The archive is still gathering evidence.';
    }
    if (score < 35 || theoryConfidence < 20) {
      return 'The archive is still weighing your recordings before naming patterns.';
    }
    if (score >= 60 && evidenceCount >= 5) {
      return 'The archive has enough evidence to detect recurring patterns.';
    }
    return 'The archive is building a clearer picture from your recordings.';
  }
}