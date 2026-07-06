import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/first_proof_moment_engine.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../retention/return_tomorrow_cue_engine.dart';
import '../retention/second_session_signal_engine.dart';
import '../return_day/return_day_flow_engine.dart';
import '../voice_capture/voice_capture_quality.dart';
import 'come_back_tomorrow_v2_copy.dart';
import 'come_back_tomorrow_v2_model.dart';
import 'come_back_tomorrow_v2_store.dart';

/// Visibility gates for Come Back Tomorrow v2.
abstract final class ComeBackTomorrowV2Gates {
  ComeBackTomorrowV2Gates._();

  static bool archiveAllows(List<JournalEntry> entries) {
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

  static bool shouldShowPostSave({
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    required ComeBackTomorrowPostSaveWatch? watch,
    required bool showFirstProofPayoff,
    required bool showFirstProofTruth,
    required bool showFirstProofActionLoop,
    required bool showWhatChangedV2Display,
    required bool showHelpedTracking,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      watch != null &&
      !showFirstProofPayoff &&
      !showFirstProofTruth &&
      !showFirstProofActionLoop &&
      !showWhatChangedV2Display &&
      !showHelpedTracking;

  static bool shouldShowQuietSignal({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required ComeBackTomorrowQuietSignal? signal,
    required bool showReturnDayFlow,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      signal != null &&
      !showReturnDayFlow;

  static bool _latestSaveIsQuietDay(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return RecordCaptureModeEngine.entryIsQuietDay(entries.first);
  }

  static bool _onlyQuietDayEntries(List<JournalEntry> entries) {
    final withText = entries
        .map(ComparableEvidenceText.userText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) return false;
    return withText.every(RecordCaptureModeEngine.isQuietDayText);
  }
}

/// Builds Come Back Tomorrow v2 surfaces from journal evidence — local only.
abstract final class ComeBackTomorrowV2Engine {
  ComeBackTomorrowV2Engine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static ComeBackTomorrowPostSaveWatch? buildPostSaveWatch({
    required List<JournalEntry> entries,
    required bool firstProofUnlocked,
  }) {
    if (!ComeBackTomorrowV2Gates.archiveAllows(entries)) return null;
    if (ComeBackTomorrowV2Gates._latestSaveIsQuietDay(entries)) return null;
    if (ComeBackTomorrowV2Gates._onlyQuietDayEntries(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final phrase = ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible);
    if (phrase == null || phrase.trim().isEmpty) return null;
    if (!_isDisplayablePhrase(phrase, eligible)) return null;

    final source = _resolvePostSaveSource(
      entries: entries,
      eligible: eligible,
      firstProofUnlocked: firstProofUnlocked,
    );
    if (source == null) return null;

    return ComeBackTomorrowPostSaveWatch(
      title: ComeBackTomorrowV2Copy.postSaveTitle,
      body: ComeBackTomorrowV2Copy.postSaveBody,
      groundedPhrase: phrase,
      footer: ComeBackTomorrowV2Copy.postSaveFooter,
      source: source,
    );
  }

  static ComeBackTomorrowReturnQuestion? buildReturnQuestion({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!ReturnDayFlowGates.archiveAllowsFlow(entries)) return null;
    if (!ReturnDayFlowGates.returnedOnLaterDay(entries: entries, now: now)) {
      return null;
    }

    final target = _resolveActiveTarget(entries);
    if (target == null) return null;

    final daysSinceSet = ComeBackTomorrowV2Store.daysSinceDateKey(
      target.createdDateKey,
      now: now,
    );

    return ComeBackTomorrowReturnQuestion(
      title: ComeBackTomorrowV2Copy.returnQuestionTitle,
      body: ComeBackTomorrowV2Copy.returnQuestionBody,
      groundedPhrase: target.groundedPhrase,
      daysSinceSet: daysSinceSet,
      source: target.source,
    );
  }

  static ComeBackTomorrowQuietSignal? buildQuietSignal({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final target = ComeBackTomorrowV2Store.active;
    if (target == null || target.quietSignalDismissed) return null;
    if (!ComeBackTomorrowV2Gates.archiveAllows(entries)) return null;

    final daysSinceSet = ComeBackTomorrowV2Store.daysSinceDateKey(
      target.createdDateKey,
      now: now,
    );
    final savesAfterSet = _savesAfterDateKey(
      entries: entries,
      dateKey: target.createdDateKey,
    );
    final unrelatedCount = savesAfterSet
        .where((entry) => !_entryMatchesWatchTarget(entry, target))
        .length;

    final shouldShow = unrelatedCount >= 2 || daysSinceSet >= 3;
    if (!shouldShow) return null;

    return ComeBackTomorrowQuietSignal(
      title: ComeBackTomorrowV2Copy.quietSignalTitle,
      body: ComeBackTomorrowV2Copy.quietSignalBody,
      footer: ComeBackTomorrowV2Copy.quietSignalFooter,
      cta: ComeBackTomorrowV2Copy.quietSignalCta,
      daysSinceSet: daysSinceSet,
      source: target.source,
    );
  }

  static ActiveWatchTarget? _resolveActiveTarget(List<JournalEntry> entries) {
    final stored = ComeBackTomorrowV2Store.active;
    if (stored != null && stored.hasGroundedPhrase) return stored;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (!ReturnDayFlowGates.hasGroundedWatchTarget(eligible)) return null;

    final phrase = ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible);
    if (phrase == null || !_isDisplayablePhrase(phrase, eligible)) return null;

    return ActiveWatchTarget(
      watchKey: ComeBackTomorrowV2Store.watchKeyForPhrase(phrase),
      groundedPhrase: phrase,
      createdDateKey: _dateKeyForEntry(eligible.last.createdAt),
      source: 'journal_grounded',
    );
  }

  static String? _resolvePostSaveSource({
    required List<JournalEntry> entries,
    required List<JournalEntry> eligible,
    required bool firstProofUnlocked,
  }) {
    if (firstProofUnlocked &&
        eligible.length >= 3 &&
        FirstProofMomentEngine.build(entries: entries) != null) {
      return 'after_first_proof';
    }
    if (eligible.length >= 2 && _signalEngine.hasGroundedRepeatMatch(eligible)) {
      return 'second_related_save';
    }
    if (eligible.length == 1) {
      return 'first_grounded_save';
    }
    return 'grounded_save';
  }

  static bool _isDisplayablePhrase(String phrase, List<JournalEntry> eligible) {
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
      label: phrase,
      entries: eligible,
    )) {
      return false;
    }
    return true;
  }

  static List<JournalEntry> _savesAfterDateKey({
    required List<JournalEntry> entries,
    required String dateKey,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    return eligible.where((entry) {
      final key = _dateKeyForEntry(entry.createdAt);
      return key.compareTo(dateKey) > 0;
    }).toList();
  }

  static bool _entryMatchesWatchTarget(
    JournalEntry entry,
    ActiveWatchTarget target,
  ) {
    final haystack = ComparableEvidenceText.userText(entry).toLowerCase();
    if (haystack.trim().isEmpty) return false;
    final phrase = target.groundedPhrase.trim().toLowerCase();
    if (phrase.length >= 8 && haystack.contains(phrase)) return true;

    final tokens = phrase
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 4)
        .toList();
    if (tokens.isEmpty) return false;
    var hits = 0;
    for (final token in tokens) {
      if (haystack.contains(token)) hits++;
    }
    return hits >= 2 || (tokens.length == 1 && hits == 1);
  }

  static String _dateKeyForEntry(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static bool isDegradedLatestSave(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return VoiceCaptureQuality.isDegradedVoiceCapture(entries.first);
  }
}
