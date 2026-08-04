import '../../models/journal_entry.dart';
import '../archive_timeline_spine/archive_timeline_spine_engine.dart';
import '../archive_timeline_spine/archive_timeline_spine_model.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../open_capture/open_capture_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../surface_priority/surface_priority_engine.dart';
import '../timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'what_to_notice_next_copy.dart';
import 'what_to_notice_next_model.dart';

/// Limits competing beta guidance cards below capture controls.
abstract final class WhatToNoticeNextSurfacePriorityAudit {
  WhatToNoticeNextSurfacePriorityAudit._();

  static bool allows({
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool openCapturePromptChipsVisible,
  }) => SurfacePriorityEngine.allowsWhatToNoticeNextOnRecord(
    lowFrictionReturnVisible: lowFrictionReturnVisible,
    betaTodaySummaryVisible: betaTodaySummaryVisible,
    openCapturePromptChipsVisible: openCapturePromptChipsVisible,
  );
}

/// Observation guidance from existing archive signals — no proof changes.
abstract final class WhatToNoticeNextEngine {
  WhatToNoticeNextEngine._();

  static const minEntryCount = 1;
  static const littleEvidenceEntryMax = 2;

  static WhatToNoticeNextResult build({
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
        (entryCount >= 3
            ? ArchiveTimelineSpineEngine.build(
                entries: entries,
                beliefSurfaceVisible: beliefSurfaceVisible,
                source: source,
                now: now,
              )
            : null);
    final timelineProof = spine != null
        ? TimelineProofMomentEngine.buildFromSpine(
            spine: spine,
            entries: entries,
            source: source,
            now: now,
          )
        : null;
    final hasTimeline =
        (spine?.shouldShow ?? false) || (timelineProof?.shouldShow ?? false);

    final usesFallbackPrompts = _usesFallbackPrompts(
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      beliefSurfaceVisible: beliefSurfaceVisible,
    );
    final promptTypes = usesFallbackPrompts
        ? WhatToNoticeNextCopy.fallbackPromptTypes
        : WhatToNoticeNextCopy.noticePromptTypes;

    return WhatToNoticeNextResult(
      shouldShow: true,
      title: WhatToNoticeNextCopy.title,
      body: WhatToNoticeNextCopy.body,
      prompts: [
        for (final type in promptTypes)
          WhatToNoticeNextPrompt(
            type: type,
            text: WhatToNoticeNextCopy.promptTextFor(type),
          ),
      ],
      closingLine: WhatToNoticeNextCopy.closingLine,
      entryCount: entryCount,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasTimeline: hasTimeline,
      usesFallbackPrompts: usesFallbackPrompts,
    );
  }

  static bool _usesFallbackPrompts({
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool beliefSurfaceVisible,
  }) =>
      entryCount <= littleEvidenceEntryMax ||
      (!hasConfirmedRepeat && !beliefSurfaceVisible);

  static bool shouldShow({
    required WhatToNoticeNextResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required int entryCount,
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool openCapturePromptChipsVisible,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (entryCount < minEntryCount) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return WhatToNoticeNextSurfacePriorityAudit.allows(
      lowFrictionReturnVisible: lowFrictionReturnVisible,
      betaTodaySummaryVisible: betaTodaySummaryVisible,
      openCapturePromptChipsVisible: openCapturePromptChipsVisible,
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
