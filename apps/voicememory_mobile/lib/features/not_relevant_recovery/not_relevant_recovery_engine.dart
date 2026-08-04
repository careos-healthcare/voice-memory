import '../../models/journal_entry.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../correction_memory/correction_memory_store.dart';
import '../current_relevance/current_relevance_model.dart';
import '../current_relevance/current_relevance_store.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'not_relevant_recovery_copy.dart';
import 'not_relevant_recovery_model.dart';
import 'not_relevant_recovery_store.dart';

/// Builds and applies not-relevant recovery from existing correction signals.
abstract final class NotRelevantRecoveryEngine {
  NotRelevantRecoveryEngine._();

  static NotRelevantRecoveryResult build({
    required List<JournalEntry> entries,
    required String source,
    DateTime? now,
  }) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) {
      return NotRelevantRecoveryResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasNotRelevantTrigger(proofKey: proofKey)) {
      return NotRelevantRecoveryResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final correction = CorrectionMemoryEngine.build(
      entries: entries,
      source: source,
      now: now,
    );

    return NotRelevantRecoveryResult(
      shouldShow: true,
      proofKey: proofKey,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasFreshReturn: correction?.returnedAfterFaded ?? false,
      title: NotRelevantRecoveryCopy.title,
      body: NotRelevantRecoveryCopy.body,
      correctionLine: NotRelevantRecoveryCopy.correctionLine,
      returnLine: NotRelevantRecoveryCopy.returnLine,
      returnedAfterCorrectionLine:
          NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
    );
  }

  static bool hasNotRelevantTrigger({required String proofKey}) {
    if (proofKey.isEmpty) return false;

    if (hasBetaNotRelevantFeedback()) return true;

    if (CurrentRelevanceStore.answerFor(proofKey) ==
        CurrentRelevanceAnswer.notReally) {
      return true;
    }

    final correction = CorrectionMemoryStore.recordFor(proofKey);
    if (correction?.state == CorrectionMemoryState.faded) {
      return true;
    }

    return false;
  }

  static bool hasBetaNotRelevantFeedback() {
    for (final surface in BetaProofFeedbackSurface.values) {
      final record = BetaProofFeedbackStore.recordFor(surface);
      if (record.answered &&
          record.feedbackType == BetaProofFeedbackType.notRelevant) {
        return true;
      }
    }
    return false;
  }

  static Future<void> syncBackgroundCorrectionIfNeeded({
    required List<JournalEntry> entries,
    required String source,
  }) async {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) return;
    if (!hasNotRelevantTrigger(proofKey: proofKey)) return;
    if (CorrectionMemoryStore.recordFor(proofKey) != null) return;

    await CorrectionMemoryEngine.saveFromAnswer(
      proofKey: proofKey,
      answer: CurrentRelevanceAnswer.notReally,
      entryCountAtCapture: entries.length,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entries,
      ),
      source: source,
    );
  }

  static Future<void> applyAction({
    required NotRelevantRecoveryResult result,
    required NotRelevantRecoveryActionType actionType,
    required String source,
    NotRelevantRecoveryStore? store,
  }) async {
    await (store ?? NotRelevantRecoveryStore.instance()).saveAction(
      proofKey: result.proofKey,
      actionType: actionType,
      entryCount: result.entryCount,
    );
    await syncCorrectionFromAction(
      result: result,
      actionType: actionType,
      source: source,
    );
  }

  static Future<void> syncCorrectionFromAction({
    required NotRelevantRecoveryResult result,
    required NotRelevantRecoveryActionType actionType,
    required String source,
  }) async {
    final answer = _answerFor(actionType);
    await CurrentRelevanceStore.instance().saveSelection(
      proofKey: result.proofKey,
      answer: answer,
      entryCountAtCapture: result.entryCount,
    );
    await CorrectionMemoryEngine.saveFromAnswer(
      proofKey: result.proofKey,
      answer: answer,
      entryCountAtCapture: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      source: source,
    );
  }

  static CurrentRelevanceAnswer _answerFor(
    NotRelevantRecoveryActionType actionType,
  ) => switch (actionType) {
    NotRelevantRecoveryActionType.keepAsBackground =>
      CurrentRelevanceAnswer.notReally,
    NotRelevantRecoveryActionType.watchLightly => CurrentRelevanceAnswer.little,
    NotRelevantRecoveryActionType.relevantAgain => CurrentRelevanceAnswer.yes,
  };

  static bool shouldShow({
    required NotRelevantRecoveryResult result,
    required bool parentVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!result.shouldShow) return false;
    if (!parentVisible) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldRender({
    required NotRelevantRecoveryResult result,
    required bool parentVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (NotRelevantRecoveryStore.isAnswered(result.proofKey)) {
      if (!parentVisible) return false;
      if (isRecording) return false;
      if (isDegradedTranscriptState) return false;
      if (isPostSaveDegradedState) return false;
      if (whatChangedQuestionActive) return false;
      if (patternReviewInboxHasActiveItems) return false;
      return true;
    }
    return shouldShow(
      result: result,
      parentVisible: parentVisible,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}
