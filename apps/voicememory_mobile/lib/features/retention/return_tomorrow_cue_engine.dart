import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/first_proof_moment_engine.dart';
import '../retention/second_session_signal_engine.dart';
import 'return_tomorrow_cue_copy.dart';
import 'return_tomorrow_cue_model.dart';

/// Visibility gates for the return-tomorrow cue.
abstract final class ReturnTomorrowCueGates {
  ReturnTomorrowCueGates._();

  static bool archiveAllowsCue(List<JournalEntry> entries) {
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

  static bool isNextDayReturn({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return false;

    final clock = now ?? DateTime.now();
    final latest = eligible
        .map((e) => e.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (_sameDay(latest, clock)) return false;

    final yesterday = clock.subtract(const Duration(days: 1));
    return _sameDay(latest, yesterday);
  }

  static bool shouldShowPostSave({
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    ReturnTomorrowCue? cue,
  }) =>
      isPostSaveDone && !isDegradedPostSave && cue != null;

  static bool shouldShowReady({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    ReturnTomorrowCue? cue,
  }) =>
      isReady && !isRecording && !isPostSave && cue != null;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Builds return-tomorrow copy from journal evidence — local only.
abstract final class ReturnTomorrowCueEngine {
  ReturnTomorrowCueEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static ReturnTomorrowCue? buildPostSave({
    required List<JournalEntry> entries,
    required bool firstProofUnlocked,
  }) {
    if (!ReturnTomorrowCueGates.archiveAllowsCue(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);

    if (firstProofUnlocked &&
        eligible.length >= 3 &&
        FirstProofMomentEngine.build(entries: entries) != null) {
      return const ReturnTomorrowCue(
        state: ReturnTomorrowCueState.afterFirstProof,
        title: ReturnTomorrowCueCopy.afterFirstProofTitle,
        body: ReturnTomorrowCueCopy.afterFirstProofBody,
      );
    }

    if (eligible.length == 1) {
      return const ReturnTomorrowCue(
        state: ReturnTomorrowCueState.afterFirstMoment,
        title: ReturnTomorrowCueCopy.afterFirstMomentTitle,
        body: ReturnTomorrowCueCopy.afterFirstMomentBody,
      );
    }

    if (eligible.length == 2 && _signalEngine.hasGroundedRepeatMatch(eligible)) {
      return const ReturnTomorrowCue(
        state: ReturnTomorrowCueState.afterSecondRelated,
        title: ReturnTomorrowCueCopy.afterSecondRelatedTitle,
        body: ReturnTomorrowCueCopy.afterSecondRelatedBody,
      );
    }

    return null;
  }

  static ReturnTomorrowCue? buildReady({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!ReturnTomorrowCueGates.archiveAllowsCue(entries)) return null;
    if (!ReturnTomorrowCueGates.isNextDayReturn(entries: entries, now: now)) {
      return null;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final phrase = groundedWatchingPhrase(eligible);

    return ReturnTomorrowCue(
      state: ReturnTomorrowCueState.nextDayReturn,
      title: ReturnTomorrowCueCopy.nextDayReturnTitle,
      body: phrase != null
          ? ReturnTomorrowCueCopy.nextDayReturnBodyWithPhrase(phrase)
          : ReturnTomorrowCueCopy.nextDayReturnBody,
      watchingPhrase: phrase,
    );
  }

  static String? groundedWatchingPhrase(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return null;

    if (eligible.length >= 2) {
      final shared =
          ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(eligible);
      if (shared != null) return shared;
    }

    final extract = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      extract.phrases,
      eligible,
    );
    if (grounded.isNotEmpty) return grounded.first;

    return ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
      eligible.last,
    );
  }

  static String? groundedWatchingPhraseFor(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    return groundedWatchingPhrase(eligible);
  }
}
