import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_tester_report/beta_tester_report_copy.dart';
import 'package:archiveme_mobile/features/beta_tester_report/beta_tester_report_model.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/features/open_capture/open_capture_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Limits beta tester report on Record when capture guidance would clutter.
abstract final class BetaTesterReportSurfacePriorityAudit {
  BetaTesterReportSurfacePriorityAudit._();

  static bool allowsOnRecord({
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool whatToNoticeNextVisible,
    required bool openCapturePromptChipsVisible,
    required bool timelineProofMomentVisible,
    required bool archiveTimelineSpineVisible,
  }) => SurfacePriorityEngine.allowsBetaTesterReportOnRecordLegacy(
    lowFrictionReturnVisible: lowFrictionReturnVisible,
    betaTodaySummaryVisible: betaTodaySummaryVisible,
    whatToNoticeNextVisible: whatToNoticeNextVisible,
    openCapturePromptChipsVisible: openCapturePromptChipsVisible,
    timelineProofMomentVisible: timelineProofMomentVisible,
    archiveTimelineSpineVisible: archiveTimelineSpineVisible,
  );
}

/// Builds a beta-first report from existing safe signals only.
abstract final class BetaTesterReportEngine {
  BetaTesterReportEngine._();

  static const minEntryCount = 3;

  static BetaTesterReportResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    DateTime? now,
    ArchiveTimelineSpineResult? timelineSpine,
  }) {
    final entryCount = entries.length;
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final spine =
        timelineSpine ??
        (entryCount >= minEntryCount
            ? ArchiveTimelineSpineEngine.build(
                entries: entries,
                beliefSurfaceVisible: beliefSurfaceVisible,
                source: source,
                now: now,
              )
            : null);
    final evidenceWeighting = entryCount >= minEntryCount
        ? EvidenceWeightingEngine.build(
            entries: entries,
            beliefSurfaceVisible: beliefSurfaceVisible,
            now: now,
          )
        : null;
    final presentDay = entryCount >= minEntryCount
        ? PresentDayRelevanceEngine.build(
            entries: entries,
            beliefSurfaceVisible: beliefSurfaceVisible,
            source: source,
            now: now,
          )
        : null;
    final correction = entryCount >= minEntryCount
        ? CorrectionMemoryEngine.snapshotFor(entries: entries, now: now)
        : null;

    final hasCorrection = correction != null;
    final hasFadingSignal = _hasFadingSignal(
      spine: spine,
      evidenceWeighting: evidenceWeighting,
      presentDay: presentDay,
    );
    final hasSofteningSignal = evidenceWeighting?.hasSofteningSignal ?? false;

    final sections = [
      for (final id in BetaTesterReportCopy.sectionOrder)
        BetaTesterReportSection(
          id: id,
          heading: BetaTesterReportCopy.headingFor(id),
          body: BetaTesterReportCopy.bodyFor(id),
        ),
    ];

    return BetaTesterReportResult(
      shouldShow: entryCount >= minEntryCount,
      title: BetaTesterReportCopy.title,
      subtitle: BetaTesterReportCopy.subtitle,
      sections: sections,
      footer: BetaTesterReportCopy.footer,
      betaFeedbackLine: BetaTesterReportCopy.betaFeedbackLine,
      entryCount: entryCount,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasCorrection: hasCorrection,
      hasFadingSignal: hasFadingSignal,
      hasSofteningSignal: hasSofteningSignal,
      sectionCount: sections.length,
    );
  }

  static bool _hasFadingSignal({
    required ArchiveTimelineSpineResult? spine,
    required EvidenceWeightingResult? evidenceWeighting,
    required PresentDayRelevanceResult? presentDay,
  }) {
    if (spine?.currentWeight == ArchiveTimelineSpineCurrentWeight.fading) {
      return true;
    }
    if (presentDay?.relevanceState == PresentDayRelevanceState.fading) {
      return true;
    }
    if (evidenceWeighting?.primaryState == EvidenceWeightState.fading) {
      return true;
    }
    return evidenceWeighting?.secondaryStates.contains(
          EvidenceWeightState.fading,
        ) ??
        false;
  }

  static bool shouldShow({
    required BetaTesterReportResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldShowOnPatterns({
    required BetaTesterReportResult? result,
    required bool patternReviewInboxHasActiveItems,
  }) => shouldShow(
    result: result,
    isReady: true,
    isRecording: false,
    isDegradedTranscriptState: false,
    firstProofPayoffVisible: false,
    whatChangedQuestionActive: false,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  );

  static bool shouldShowOnRecord({
    required BetaTesterReportResult? result,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool whatToNoticeNextVisible,
    required bool openCapturePromptChipsVisible,
    required bool timelineProofMomentVisible,
    required bool archiveTimelineSpineVisible,
  }) {
    if (!shouldShow(
      result: result,
      isReady: true,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      firstProofPayoffVisible: firstProofPayoffVisible,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    )) {
      return false;
    }
    return BetaTesterReportSurfacePriorityAudit.allowsOnRecord(
      lowFrictionReturnVisible: lowFrictionReturnVisible,
      betaTodaySummaryVisible: betaTodaySummaryVisible,
      whatToNoticeNextVisible: whatToNoticeNextVisible,
      openCapturePromptChipsVisible: openCapturePromptChipsVisible,
      timelineProofMomentVisible: timelineProofMomentVisible,
      archiveTimelineSpineVisible: archiveTimelineSpineVisible,
    );
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => OpenCaptureEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}