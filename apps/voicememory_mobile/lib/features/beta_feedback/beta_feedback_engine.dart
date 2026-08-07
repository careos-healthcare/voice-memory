import '../../models/journal_entry.dart';
import '../archive_depth/archive_depth_engine.dart';
import '../demo/sample_archive_mode.dart';
import 'beta_feedback_copy.dart';
import 'beta_feedback_models.dart';

/// Deterministic beta proof builder — local metadata only.
class BetaFeedbackEngine {
  const BetaFeedbackEngine();

  int realEntryCount(List<JournalEntry> entries) => realEntryCountFor(entries);

  static int realEntryCountFor(List<JournalEntry> entries) {
    return SampleArchiveMode.excludeSampleEntries(entries)
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .length;
  }

  BetaFeedbackSummary buildSummary({
    required List<JournalEntry> entries,
    required int watchThemesCount,
    required BetaFeedbackState feedbackState,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries)
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .toList();
    final depth = const ArchiveDepthEngine().build(entries: realEntries);
    return BetaFeedbackSummary(
      momentsSavedCount: realEntries.length,
      depthLevelLabel: depth.levelLabel,
      watchThemesCount: watchThemesCount,
      usefulnessLabel: BetaFeedbackCopy.usefulnessLabel(
        feedbackState.usefulness,
      ),
      clarityLabel: BetaFeedbackCopy.clarityLabel(feedbackState.clarity),
      hasPrivateEntries: false,
      feedbackState: feedbackState,
    );
  }
}
