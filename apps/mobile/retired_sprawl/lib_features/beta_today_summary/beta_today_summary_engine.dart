import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_today_summary/beta_today_summary_copy.dart';
import 'package:archiveme_mobile/features/beta_today_summary/beta_today_summary_model.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/features/open_capture/open_capture_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds a lightweight today summary from existing archive signals only.
abstract final class BetaTodaySummaryEngine {
  BetaTodaySummaryEngine._();

  static BetaTodaySummaryResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    DateTime? now,
  }) {
    final entryCount = entries.length;
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final spine = ArchiveTimelineSpineEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );
    final evidenceWeighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      now: now,
    );
    final presentDay = PresentDayRelevanceEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );
    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final hasCorrection = correction != null;

    final littleEvidence = _hasLittleEvidence(
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      beliefSurfaceVisible: beliefSurfaceVisible,
      spine: spine,
      evidenceWeighting: evidenceWeighting,
    );

    final hasFadingSignal = _hasFadingSignal(
      spine: spine,
      evidenceWeighting: evidenceWeighting,
      presentDay: presentDay,
    );
    final needsFreshProof = _needsFreshProof(
      spine: spine,
      evidenceWeighting: evidenceWeighting,
    );
    final hasActivePattern = _hasActivePattern(
      hasConfirmedRepeat: hasConfirmedRepeat,
      spine: spine,
      evidenceWeighting: evidenceWeighting,
      presentDay: presentDay,
    );

    final rows = <String>[];
    if (hasCorrection) {
      rows.add(BetaTodaySummaryCopy.correctionRow);
    }
    if (needsFreshProof) {
      rows.add(BetaTodaySummaryCopy.needsFreshProofRow);
    }
    if (hasFadingSignal) {
      rows.add(BetaTodaySummaryCopy.fadingRow);
    }
    if (hasActivePattern) {
      rows.add(BetaTodaySummaryCopy.activePatternRow);
    }
    if (littleEvidence && rows.isEmpty) {
      rows.add(BetaTodaySummaryCopy.noStrongPatternRow);
    } else if (rows.isEmpty) {
      rows.add(BetaTodaySummaryCopy.nothingUrgentRow);
    }

    return BetaTodaySummaryResult(
      shouldShow: true,
      title: BetaTodaySummaryCopy.title,
      body: littleEvidence
          ? BetaTodaySummaryCopy.fallbackBody
          : BetaTodaySummaryCopy.primaryBody,
      summaryRows: rows,
      closingLine: BetaTodaySummaryCopy.closingLine,
      entryCount: entryCount,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasCorrection: hasCorrection,
      hasActivePattern: hasActivePattern,
      hasFadingSignal: hasFadingSignal,
      usesFallbackBody: littleEvidence,
    );
  }

  static bool _hasLittleEvidence({
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool beliefSurfaceVisible,
    required ArchiveTimelineSpineResult? spine,
    required EvidenceWeightingResult? evidenceWeighting,
  }) =>
      entryCount < 3 ||
      (!hasConfirmedRepeat && !beliefSurfaceVisible) ||
      (spine == null && evidenceWeighting == null);

  static bool _needsFreshProof({
    required ArchiveTimelineSpineResult? spine,
    required EvidenceWeightingResult? evidenceWeighting,
  }) {
    if (spine?.currentWeight ==
        ArchiveTimelineSpineCurrentWeight.needsFreshProof) {
      return true;
    }
    if (spine?.rows.any(
          (row) => row.id == ArchiveTimelineSpineRowId.needsFreshProof,
        ) ??
        false) {
      return true;
    }
    if (evidenceWeighting?.primaryState ==
        EvidenceWeightState.needsFreshProof) {
      return true;
    }
    return evidenceWeighting?.secondaryStates.contains(
          EvidenceWeightState.needsFreshProof,
        ) ??
        false;
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

  static bool _hasActivePattern({
    required bool hasConfirmedRepeat,
    required ArchiveTimelineSpineResult? spine,
    required EvidenceWeightingResult? evidenceWeighting,
    required PresentDayRelevanceResult? presentDay,
  }) {
    if (!hasConfirmedRepeat) return false;
    final weight = spine?.currentWeight;
    if (weight == ArchiveTimelineSpineCurrentWeight.strong ||
        weight == ArchiveTimelineSpineCurrentWeight.light) {
      return true;
    }
    if (presentDay?.relevanceState == PresentDayRelevanceState.current) {
      return true;
    }
    final primary = evidenceWeighting?.primaryState;
    return primary == EvidenceWeightState.fresh ||
        primary == EvidenceWeightState.repeated;
  }

  static bool shouldShow({
    required BetaTodaySummaryResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => OpenCaptureEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}