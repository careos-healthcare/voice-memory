import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../belief_change/belief_change_moment_engine.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/first_proof_moment_engine.dart';
import '../pattern_detail/pattern_detail_engine.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../retention/return_tomorrow_cue_engine.dart';
import '../return_day/return_day_flow_engine.dart';
import 'daily_archive_memory_copy.dart';
import 'daily_archive_memory_model.dart';

/// Visibility gates for the daily archive memory card.
abstract final class DailyArchiveMemoryGates {
  DailyArchiveMemoryGates._();

  static bool archiveAllows(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;
    if (_onlyQuietDayEntries(entries)) return false;
    return true;
  }

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required DailyArchiveMemoryResult? memory,
    required bool showReturnDayFlow,
    required bool showReturnTomorrowCueReady,
    required bool showLowEvidenceGuidance,
    required bool showWeeklyArchiveReview,
    required bool firstProofLoopActive,
    bool showComeBackTomorrowQuietSignal = false,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount >= 1 &&
      memory != null &&
      !showReturnDayFlow &&
      !showReturnTomorrowCueReady &&
      !showLowEvidenceGuidance &&
      !showWeeklyArchiveReview &&
      !firstProofLoopActive &&
      !showComeBackTomorrowQuietSignal;

  static bool _onlyQuietDayEntries(List<JournalEntry> entries) {
    final withText = entries
        .map(ComparableEvidenceText.userText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) return false;
    return withText.every(RecordCaptureModeEngine.isQuietDayText);
  }
}

/// Builds returning-user memory copy from existing watch-target engines only.
abstract final class DailyArchiveMemoryEngine {
  DailyArchiveMemoryEngine._();

  static DailyArchiveMemoryResult? build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!DailyArchiveMemoryGates.archiveAllows(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final watchPhrase = _resolveWatchPhrase(
      entries: entries,
      eligible: eligible,
      confirmedRepeat: confirmedRepeat,
      changeProof: changeProof,
      returnChecks: returnChecks,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );
    final canShowPatternDetail =
        viewingConfirmedRepeatOrTimeline &&
        PatternDetailEngine.canShow(
          entries: entries,
          confirmedRepeat: confirmedRepeat,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
        );

    if (watchPhrase != null) {
      return DailyArchiveMemoryResult(
        title: DailyArchiveMemoryCopy.watchTitle,
        body: DailyArchiveMemoryCopy.watchBody,
        watchPhrase: watchPhrase,
        footer: DailyArchiveMemoryCopy.footer,
        hasWatchTarget: true,
        canShowPatternDetail: canShowPatternDetail,
      );
    }

    return const DailyArchiveMemoryResult(
      title: DailyArchiveMemoryCopy.fallbackTitle,
      body: DailyArchiveMemoryCopy.fallbackBody,
      hasWatchTarget: false,
      canShowPatternDetail: false,
    );
  }

  static String? _resolveWatchPhrase({
    required List<JournalEntry> entries,
    required List<JournalEntry> eligible,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (eligible.length >= 3 &&
        FirstProofMomentEngine.build(entries: entries) != null) {
      final phrase = _displayPhrase(
        ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible),
        eligible,
      );
      if (phrase != null) return phrase;
    }

    if (ReturnDayFlowGates.hasGroundedWatchTarget(eligible)) {
      final phrase = _displayPhrase(
        ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible),
        eligible,
      );
      if (phrase != null) return phrase;
    }

    if (viewingConfirmedRepeatOrTimeline) {
      final detail = PatternDetailEngine.build(
        entries: entries,
        confirmedRepeat: confirmedRepeat,
        changeProof: changeProof,
        returnChecks: returnChecks,
        triggerCapturedMilestone: triggerCapturedMilestone,
        helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      );
      final label = detail?.patternLabel.trim();
      if (label != null && label.isNotEmpty) return label;
    }

    final beliefChange = BeliefChangeMomentEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );
    final beliefPhrase = beliefChange?.earlierBeliefExample.trim();
    if (beliefPhrase != null && beliefPhrase.isNotEmpty) {
      return beliefPhrase;
    }

    final phrase = _displayPhrase(
      ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible),
      eligible,
    );
    return phrase;
  }

  static String? _displayPhrase(String? raw, List<JournalEntry> eligible) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(raw)) return null;
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(raw)) {
      return null;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
      label: raw,
      entries: eligible,
    )) {
      return null;
    }
    return PatternNameEngine.displayLabelForGroundedPhrase(raw);
  }
}
