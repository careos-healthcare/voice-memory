import '../../models/journal_entry.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'confirmed_repeat_thought_map_engine.dart';
import 'confirmed_repeat_thought_map_models.dart';
import 'daily_return_reason_engine.dart';
import 'daily_return_reason_model.dart';
import 'early_evidence_timeline_engine.dart';
import 'early_first_signal_engine.dart';
import 'positive_pattern_engine.dart';
import 'positive_pattern_models.dart';
import 'positive_reinforcement_engine.dart';
import 'private_archive_report_copy.dart';
import 'private_archive_report_model.dart';
import 'weekly_archive_review_copy.dart';
import 'weekly_archive_review_engine.dart';
import 'weekly_archive_review_model.dart';

/// Builds a private archive report from existing proof engines only.
abstract final class PrivateArchiveReportEngine {
  PrivateArchiveReportEngine._();

  static PrivateArchiveReport? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;

    final confirmedRepeat = EarlyFirstSignalEngine.build(entries: entries);
    final timeline = EarlyEvidenceTimelineEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    final changeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
      records: returnChecks,
    );
    final thoughtMap = ConfirmedRepeatThoughtMapEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
    );
    final positivePattern = PositivePatternEngine.build(entries: entries);
    final positiveReinforcement = PositiveReinforcementEngine.build(
      positivePattern: positivePattern,
      entries: entries,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    final weeklyReview = WeeklyArchiveWeekReviewEngine.build(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    final dailyReason = DailyReturnReasonEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );

    final report = PrivateArchiveReport(
      title: PrivateArchiveReportCopy.title,
      intro: PrivateArchiveReportCopy.intro,
      sections: [
        _repeatingSection(confirmedRepeat: confirmedRepeat, timeline: timeline),
        _loopSection(thoughtMap),
        _changedSection(changeProof),
        _helpedSection(positiveReinforcement, positivePattern),
        _thisWeekSection(weeklyReview),
        _recordNextSection(dailyReason),
      ],
    );

    if (!report.hasContent) return null;
    if (!_hasRepeatEvidence(report)) return null;
    return report;
  }

  static bool _hasRepeatEvidence(PrivateArchiveReport report) {
    final repeating = report.sections.first;
    return repeating.bullets.isNotEmpty || repeating.lines.isNotEmpty;
  }

  static PrivateArchiveReportSection _repeatingSection({
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
  }) {
    if (confirmedRepeat?.showsConfirmedRepeat == true) {
      return PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatKeepsRepeatingHeading,
        lines: [
          confirmedRepeat!.title,
          ...confirmedRepeat.lines,
        ],
        bullets: confirmedRepeat.evidencePhrases,
      );
    }

    if (timeline != null) {
      final repeatItem = timeline.items
          .where(
            (item) => item.kind == EarlyEvidenceTimelineItemKind.repeatConfirmed,
          )
          .firstOrNull;
      return PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatKeepsRepeatingHeading,
        lines: [
          if (repeatItem != null) repeatItem.title,
          if (repeatItem != null) repeatItem.body,
        ],
        bullets: timeline.evidencePhrases,
      );
    }

    return const PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatKeepsRepeatingHeading,
    );
  }

  static PrivateArchiveReportSection _loopSection(ThoughtMapResult? thoughtMap) {
    if (thoughtMap == null) {
      return const PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.loopHeading,
      );
    }

    final lines = <String>[
      thoughtMap.title,
      for (final section in thoughtMap.sections)
        '${section.label}: ${section.displayText}',
    ];

    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.loopHeading,
      lines: lines,
    );
  }

  static PrivateArchiveReportSection _changedSection(
    RepeatReturnCheckChangeProof? changeProof,
  ) {
    if (changeProof == null || changeProof.body.trim().isEmpty) {
      return const PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatChangedHeading,
      );
    }

    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatChangedHeading,
      lines: [changeProof.title, changeProof.body],
    );
  }

  static PrivateArchiveReportSection _helpedSection(
    PositiveReinforcementResult? reinforcement,
    PositivePatternResult? pattern,
  ) {
    if (reinforcement != null && reinforcement.hasEvidence) {
      return PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatHelpedHeading,
        lines: [reinforcement.title, reinforcement.body],
        bullets: reinforcement.evidencePhrases,
      );
    }

    if (pattern != null && pattern.hasEvidence) {
      return PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatHelpedHeading,
        lines: [pattern.title, pattern.body],
        bullets: pattern.evidencePhrases,
      );
    }

    return const PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatHelpedHeading,
    );
  }

  static PrivateArchiveReportSection _thisWeekSection(
    WeeklyArchiveWeekReviewResult review,
  ) {
    if (!review.hasRepeat && !review.hasChange && !review.hasPositivePattern) {
      return const PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.thisWeekHeading,
      );
    }

    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.thisWeekHeading,
      lines: [
        review.title,
        review.promise,
        '${WeeklyArchiveWeekReviewCopy.repeatedLabel}: ${review.repeatedLine}',
        '${WeeklyArchiveWeekReviewCopy.changedLabel}: ${review.changedLine}',
        '${WeeklyArchiveWeekReviewCopy.helpedLabel}: ${review.helpedLine}',
        '${WeeklyArchiveWeekReviewCopy.nextToWatchLabel}: ${review.nextToWatchLine}',
      ],
      bullets: review.evidencePhrases,
    );
  }

  static PrivateArchiveReportSection _recordNextSection(
    DailyReturnReasonResult? reason,
  ) {
    if (reason == null) {
      return const PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.recordNextHeading,
      );
    }

    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.recordNextHeading,
      lines: [reason.title, reason.body, reason.prompt],
    );
  }
}
