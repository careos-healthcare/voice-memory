import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_engine.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Counts evidence milestones that justify paywall timing — not raw entry totals
/// or streak-style frequency. Each increment maps to a distinct proof category;
/// overlapping signals from the same thread never stack.
abstract final class MagicMomentsCounter {
  MagicMomentsCounter._();

  static const paywallThreshold = 3;

  static const _threadEngine = ThreadReturnEvidenceEngine();
  static const _beliefEngine = BeliefDistanceEngine();
  static const _weeklyEngine = WeeklyThreadReviewEngine();

  static bool paywallEligible(int evidenceMilestoneCount) =>
      evidenceMilestoneCount >= paywallThreshold;

  /// Distinct journal milestones: early two-entry pattern, confirmed repeat,
  /// and evidence timeline — never double-counting kind vs foundation.
  static int countFromJournalEntries(List<JournalEntry> entries) {
    final eligible = SampleArchiveMode.excludeSampleEntries(entries);
    if (eligible.isEmpty) return 0;

    var count = 0;
    final earlySignal = EarlyFirstSignalEngine.build(entries: eligible);

    if (_hasTwoEntryPatternMilestone(eligible, earlySignal?.kind)) {
      count++;
    }

    if (earlySignal?.kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat ||
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(eligible)) {
      count++;
    }

    if (EarlyEvidenceTimelineEngine.build(entries: eligible) != null) {
      count++;
    }

    return count;
  }

  /// Distinct pressure-retention milestones: thread depth (early + strong),
  /// belief repetition, weekly review. Connected-recording count is not
  /// counted separately — it comes from the same thread engine.
  static int countFromPressureRecords(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    if (records.isEmpty) return 0;
    var count = 0;

    final thread = _threadEngine.build(records, now: now);
    if (thread.hasEvidence) {
      count++;
      if (thread.occurrenceCount >=
          ThreadReturnEvidence.minOccurrencesForStrongLanguage) {
        count++;
      }
    }

    if (_beliefEngine.build(records).hasBelief) count++;
    if (_weeklyEngine.build(records, now: now).hasReview) count++;

    return count;
  }

  /// Raw saved-entry count for beta feedback only — never a paywall gate.
  static int countSavedMoments(List<JournalEntry> entries) =>
      BetaFeedbackEngine.realEntryCountFor(entries);

  static bool _hasTwoEntryPatternMilestone(
    List<JournalEntry> eligible,
    EarlyFirstSignalKind? currentKind,
  ) {
    if (currentKind == EarlyFirstSignalKind.twoEntryFirstSignal) return true;
    if (eligible.length < 3) return false;
    final priorTwo = EarlyFirstSignalEngine.build(
      entries: eligible.sublist(0, 2),
    );
    return priorTwo?.kind == EarlyFirstSignalKind.twoEntryFirstSignal;
  }
}