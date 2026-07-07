import '../../models/journal_entry.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../quiet_signal/quiet_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'evidence_weighting_model.dart';

/// Lightweight evidence freshness weighting — explanation only, no proof changes.
abstract final class EvidenceWeightingEngine {
  EvidenceWeightingEngine._();

  static const minEntryCount = 3;
  static const recentWindowDays = 7;

  static EvidenceWeightingResult? build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    DateTime? now,
  }) {
    if (entries.length < minEntryCount) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) return null;
    if (!_passesEvidenceQuality(entries)) return null;

    final clock = now ?? DateTime.now();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final hasRecentEntry = _hasRecentEntry(eligible, clock);
    final hasOlderEntry = _hasOlderEntry(eligible, clock);
    final hasSofteningSignal =
        EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries);
    final hasQuietSignal = QuietSignalEngine.build(
          entries: entries,
          now: clock,
        ) !=
        null;

    final secondary = <EvidenceWeightState>[];
    final primary = _resolvePrimaryState(
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasRecentEntry: hasRecentEntry,
      hasOlderEntry: hasOlderEntry,
    );

    if (hasRecentEntry && primary != EvidenceWeightState.fresh) {
      secondary.add(EvidenceWeightState.fresh);
    }
    if (hasQuietSignal || (hasOlderEntry && !hasRecentEntry && hasConfirmedRepeat)) {
      _addSecondary(secondary, EvidenceWeightState.fading);
    }
    if (hasSofteningSignal) {
      _addSecondary(secondary, EvidenceWeightState.softened);
    }
    if (hasOlderEntry &&
        !hasRecentEntry &&
        primary != EvidenceWeightState.needsFreshProof &&
        primary != EvidenceWeightState.oldSignal) {
      _addSecondary(
        secondary,
        hasConfirmedRepeat
            ? EvidenceWeightState.oldSignal
            : EvidenceWeightState.needsFreshProof,
      );
    }

    return EvidenceWeightingResult(
      entryCount: entries.length,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasRecentEntry: hasRecentEntry,
      hasOlderEntry: hasOlderEntry,
      hasSofteningSignal: hasSofteningSignal,
      hasQuietSignal: hasQuietSignal,
      primaryState: primary,
      secondaryStates: secondary,
      shouldShow: true,
      correctionMemory: CorrectionMemoryEngine.snapshotFor(
        entries: entries,
        now: clock,
      ),
    );
  }

  static bool shouldShow({
    required EvidenceWeightingResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isZeroEntryState) return false;
    if (isFirstRecordingState) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldShowOnRecordReady({
    required EvidenceWeightingResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnPatterns({
    required EvidenceWeightingResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static EvidenceWeightState _resolvePrimaryState({
    required bool hasConfirmedRepeat,
    required bool hasRecentEntry,
    required bool hasOlderEntry,
  }) {
    if (hasConfirmedRepeat && hasRecentEntry) {
      return EvidenceWeightState.repeated;
    }
    if (hasRecentEntry) {
      return EvidenceWeightState.fresh;
    }
    if (hasOlderEntry && hasConfirmedRepeat) {
      return EvidenceWeightState.needsFreshProof;
    }
    if (hasOlderEntry) {
      return EvidenceWeightState.oldSignal;
    }
    return EvidenceWeightState.fresh;
  }

  static bool _hasRecentEntry(List<JournalEntry> eligible, DateTime now) {
    if (eligible.isEmpty) return false;
    final latest = eligible.last.createdAt;
    return now.difference(latest).inDays <= recentWindowDays;
  }

  static bool _hasOlderEntry(List<JournalEntry> eligible, DateTime now) {
    if (eligible.length < 2) return false;
    final cutoff = now.subtract(const Duration(days: recentWindowDays));
    return eligible.any((entry) => entry.createdAt.isBefore(cutoff));
  }

  static void _addSecondary(
    List<EvidenceWeightState> secondary,
    EvidenceWeightState state,
  ) {
    if (!secondary.contains(state)) {
      secondary.add(state);
    }
  }

  static bool _passesEvidenceQuality(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return true;
  }
}
