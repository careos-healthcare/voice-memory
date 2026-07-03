import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/first_proof_moment_engine.dart';
import '../retention/second_session_signal_engine.dart';
import '../trust/capture_recovery_gates.dart';
import 'return_tomorrow_cue_engine.dart';
import 'yesterday_watch_copy.dart';
import 'yesterday_watch_model.dart';
import 'yesterday_watch_store.dart';

/// Visibility gates for the yesterday-watch card.
abstract final class YesterdayWatchGates {
  YesterdayWatchGates._();

  static bool archiveAllowsWatch(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;
    return true;
  }

  /// Last save was yesterday — completes the return-tomorrow loop.
  static bool returnedOnLaterDay({
    required List<JournalEntry> entries,
    DateTime? now,
  }) =>
      ReturnTomorrowCueGates.isNextDayReturn(entries: entries, now: now);

  static bool hasWatchTarget(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return false;

    if (eligible.length >= 3 &&
        FirstProofMomentEngine.build(entries: eligible) != null) {
      return true;
    }

    if (eligible.length >= 2 &&
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(eligible)) {
      return true;
    }

    if (ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible) != null) {
      return true;
    }

    return eligible.length >= 1;
  }

  static bool shouldShow({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    YesterdayWatch? watch,
    required bool dismissedToday,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      watch != null &&
      !dismissedToday;
}

/// Builds yesterday-watch content from journal evidence — local only.
abstract final class YesterdayWatchEngine {
  YesterdayWatchEngine._();

  static YesterdayWatch? build({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!YesterdayWatchGates.archiveAllowsWatch(entries)) return null;
    if (!YesterdayWatchGates.returnedOnLaterDay(entries: entries, now: now)) {
      return null;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (!YesterdayWatchGates.hasWatchTarget(eligible)) return null;

    final days = CaptureRecoveryGates.daysSinceLastEntry(entries: entries, now: now);
    final phrase = ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible);

    return YesterdayWatch(
      title: phrase != null
          ? YesterdayWatchCopy.titleWithPhrase(phrase)
          : YesterdayWatchCopy.defaultTitle,
      body: phrase != null
          ? YesterdayWatchCopy.phraseBody
          : YesterdayWatchCopy.defaultBody,
      daysSinceLastEntry: days,
      watchingPhrase: phrase,
    );
  }

  static bool shouldHideForDismissal() => YesterdayWatchStore.isDismissedToday;
}
