import '../archive_evidence/archive_belief_thread_copy.dart';
import '../early_archive/early_evidence_timeline_copy.dart';
import '../early_archive/early_first_signal_copy.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import 'archive_proof_surface_layout.dart';
import 'archive_summary_copy.dart';
import 'confirmed_repeat_thought_map_copy.dart';
import 'confirmed_repeat_why_matters_copy.dart';
import 'daily_return_reason_copy.dart';
import 'positive_pattern_copy.dart';
import 'positive_reinforcement_copy.dart';
import 'private_archive_report_copy.dart';
import 'weekly_archive_review_copy.dart';
import 'early_evidence_timeline_engine.dart';

/// Resolves de-duplicated visible copy for proof stacks (tests + policy).
abstract final class ArchiveProofSurfaceCopy {
  ArchiveProofSurfaceCopy._();

  static List<String> recordReadyStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
    bool showArchiveSummary = false,
    bool showDailyReturnReason = false,
    bool showWeeklyReview = false,
    bool showPrivateReport = false,
    bool showPatternChanged = false,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
        patternChanged: patternChanged,
        surfaceIsRecord: true,
        showArchiveSummary: showArchiveSummary,
        showDailyReturnReason: showDailyReturnReason,
        showWeeklyReview: showWeeklyReview,
        showPrivateReport: showPrivateReport,
        showPatternChanged: showPatternChanged,
      );

  static List<String> patternsStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
        patternChanged: patternChanged,
      );

  static List<String> _stack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
    bool surfaceIsRecord = false,
    bool showArchiveSummary = false,
    bool showDailyReturnReason = false,
    bool showWeeklyReview = false,
    bool showPrivateReport = false,
    bool showPatternChanged = false,
  }) {
    final blocks = <String>[];
    final summaryVisible =
        showArchiveSummary || (layout.archiveSummaryVisible && !surfaceIsRecord);
    final patternChangedVisible = surfaceIsRecord
        ? showPatternChanged
        : layout.effectivePatternChangedVisible;
    final timelineVisible = layout.recordTimelineVisible(
      surfaceIsRecord: surfaceIsRecord,
    );

    if (layout.effectiveConfirmedRepeatCardVisible && confirmedRepeat != null) {
      blocks.add(confirmedRepeat.title);
      blocks.addAll(confirmedRepeat.lines);
      if (confirmedRepeat.evidenceHeading != null) {
        blocks.add(confirmedRepeat.evidenceHeading!);
      }
      blocks.addAll(confirmedRepeat.evidencePhrases);
      if (confirmedRepeat.evidenceSupportLine != null) {
        blocks.add(confirmedRepeat.evidenceSupportLine!);
      }
    }

    if (timelineVisible && timeline != null) {
      blocks.add(
        layout.timelineNearby
            ? EarlyEvidenceTimelineCopy.nearbyTitle
            : timeline.title,
      );
      blocks.add(
        layout.timelineNearby
            ? EarlyEvidenceTimelineCopy.nearbySubtitle
            : timeline.subtitle,
      );
      if (!layout.suppressTimelineEvidencePhrases) {
        blocks.add(EarlyFirstSignalCopy.evidenceHeading);
        blocks.addAll(timeline.evidencePhrases);
      }
      for (final item in timeline.items) {
        blocks.add(item.title);
        if (!(layout.timelineNearby &&
            item.kind == EarlyEvidenceTimelineItemKind.repeatConfirmed)) {
          blocks.add(item.body);
        }
      }
    }

    if (patternChangedVisible && patternChanged != null) {
      blocks.add(patternChanged.title);
      blocks.add(patternChanged.body);
    } else if (layout.effectiveChangeProofVisible && changeProof != null) {
      if (!summaryVisible) {
        blocks.add(changeProof.title);
        blocks.add(changeProof.body);
        if (changeProof.supportLine != null) {
          blocks.add(changeProof.supportLine!);
        }
      }
    }

    if (summaryVisible) {
      blocks.add(ArchiveSummaryCopy.title);
      blocks.add(ArchiveSummaryCopy.keepsRepeatingLabel);
      if (layout.thoughtMapVisible || summaryVisible) {
        blocks.add(ArchiveSummaryCopy.loopFormingLabel);
      }
      blocks.add(ArchiveSummaryCopy.changingLabel);
      blocks.add(ArchiveSummaryCopy.whatHelpsLabel);
      blocks.add(ArchiveSummaryCopy.recordNextLabel);
    }

    if (showDailyReturnReason) {
      blocks.add(DailyReturnReasonCopy.title);
    }

    if (showWeeklyReview && surfaceIsRecord) {
      blocks.add(WeeklyArchiveWeekReviewCopy.title);
    }

    if (showPrivateReport && surfaceIsRecord) {
      blocks.add(PrivateArchiveReportCopy.title);
    }

    if (layout.proBridgeVisible) {
      blocks.add(ArchiveBeliefThreadCopy.fullArchiveHistoryTitle);
      blocks.add(ArchiveBeliefThreadCopy.fullArchiveHistoryBody);
      blocks.addAll(ArchiveBeliefThreadCopy.fullArchiveHistoryBullets);
    }

    if (layout.whyMattersVisible && !layout.archiveSummaryVisible) {
      blocks.add(ConfirmedRepeatWhyMattersCopy.title);
      blocks.add(ConfirmedRepeatWhyMattersCopy.body);
    }

    if (layout.thoughtMapVisible && !layout.archiveSummaryVisible) {
      blocks.add(ConfirmedRepeatThoughtMapCopy.title);
      for (final label in [
        ConfirmedRepeatThoughtMapCopy.triggerLabel,
        ConfirmedRepeatThoughtMapCopy.thoughtLabel,
        ConfirmedRepeatThoughtMapCopy.actionLabel,
        ConfirmedRepeatThoughtMapCopy.resultLabel,
      ]) {
        blocks.add(label);
      }
    }

    if (layout.effectivePositiveReinforcementVisible) {
      blocks.add(PositiveReinforcementCopy.title);
      blocks.add(PositiveReinforcementCopy.body);
    } else if (layout.effectivePositivePatternVisible) {
      blocks.add(PositivePatternCopy.title);
      blocks.add(PositivePatternCopy.body);
    }

    return blocks.where((block) => block.trim().isNotEmpty).toList();
  }
}
