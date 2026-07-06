import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_engine.dart';
import '../early_archive/first_proof_moment_engine.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../retention/return_tomorrow_cue_engine.dart';
import '../retention/second_session_signal_engine.dart';
import '../trust/capture_recovery_gates.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import 'return_day_flow_model.dart';
import 'return_day_flow_store.dart';

/// Visibility gates for Return Day Flow v2.
abstract final class ReturnDayFlowGates {
  ReturnDayFlowGates._();

  static bool archiveAllowsFlow(List<JournalEntry> entries) {
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

  /// Last save was yesterday — completes the return-tomorrow loop.
  static bool returnedOnLaterDay({
    required List<JournalEntry> entries,
    DateTime? now,
  }) =>
      ReturnTomorrowCueGates.isNextDayReturn(entries: entries, now: now);

  /// Requires a grounded watch target — no loose single-entry fallback.
  static bool hasGroundedWatchTarget(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return false;

    if (eligible.length >= 3 &&
        FirstProofMomentEngine.build(entries: eligible) != null) {
      return true;
    }

    if (eligible.length >= 2 &&
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(eligible)) {
      return true;
    }

    return ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible) != null;
  }

  static bool shouldShow({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    ReturnDayFlow? flow,
    required bool dismissedToday,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      flow != null &&
      !dismissedToday;

  static bool _onlyQuietDayEntries(List<JournalEntry> entries) {
    final withText = entries
        .map(ComparableEvidenceText.userText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) return false;
    return withText.every(RecordCaptureModeEngine.isQuietDayText);
  }
}

/// Builds Return Day Flow v2 content from journal evidence — local only.
abstract final class ReturnDayFlowEngine {
  ReturnDayFlowEngine._();

  static ReturnDayFlow? build({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!ReturnDayFlowGates.archiveAllowsFlow(entries)) return null;
    if (!ReturnDayFlowGates.returnedOnLaterDay(entries: entries, now: now)) {
      return null;
    }

    final question = ComeBackTomorrowV2Engine.buildReturnQuestion(
      entries: entries,
      now: now,
    );
    if (question == null) return null;

    final days = CaptureRecoveryGates.daysSinceLastEntry(entries: entries, now: now);

    return ReturnDayFlow(
      title: question.title,
      body: question.body,
      daysSinceLastEntry: days,
      watchingPhrase: question.groundedPhrase,
      source: question.source,
      daysSinceSet: question.daysSinceSet,
    );
  }

  static bool shouldHideForDismissal() => ReturnDayFlowStore.isDismissedToday;
}
