import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'current_relevance_model.dart';
import 'current_relevance_store.dart';

/// Builds current relevance state and visibility gates — correction, not proof.
abstract final class CurrentRelevanceEngine {
  CurrentRelevanceEngine._();

  static const minEntryCount = 3;

  static const answerOptions = [
    CurrentRelevanceAnswer.yes,
    CurrentRelevanceAnswer.little,
    CurrentRelevanceAnswer.notReally,
    CurrentRelevanceAnswer.notSure,
  ];

  static CurrentRelevanceState? build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
  }) {
    if (entries.length < minEntryCount) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) return null;
    if (!_passesEvidenceQuality(entries)) return null;

    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) return null;

    return CurrentRelevanceState(
      proofKey: proofKey,
      entryCount: entries.length,
      hasConfirmedRepeat: hasConfirmedRepeat,
      answer: CurrentRelevanceStore.answerFor(proofKey),
    );
  }

  static bool shouldShow({
    required CurrentRelevanceState? state,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (state == null) return false;
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
    required CurrentRelevanceState? state,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (state == null || !state.hasConfirmedRepeat) return false;
    return shouldShow(
      state: state,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofPayoffVisible: firstProofPayoffVisible,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static bool shouldShowOnPatterns({
    required CurrentRelevanceState? state,
    required bool beliefSurfaceVisible,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (state == null) return false;
    if (!state.hasConfirmedRepeat && !beliefSurfaceVisible) return false;
    return shouldShow(
      state: state,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofPayoffVisible: firstProofPayoffVisible,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static bool isQuestionActive({
    required CurrentRelevanceState? state,
    required bool visible,
  }) => visible && state != null && state.isQuestionActive;

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );

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
