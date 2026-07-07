import '../../models/journal_entry.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../current_relevance/current_relevance_store.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../not_relevant_recovery/not_relevant_recovery_copy.dart';
import '../not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../not_relevant_recovery/not_relevant_recovery_model.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../evidence_anchors/evidence_anchor_engine.dart';
import '../pattern_match_quality/pattern_match_quality_analytics.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_analytics.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'proof_quality_response_copy.dart';
import 'proof_quality_response_model.dart';
import 'proof_quality_response_store.dart';

/// Builds and applies proof quality responses from beta feedback signals.
abstract final class ProofQualityResponseEngine {
  ProofQualityResponseEngine._();

  static ProofQualityResponseResult build({
    required List<JournalEntry> entries,
    required ProofQualityResponseSurface surface,
    required String source,
    List<String> beliefEvidencePhrases = const [],
    DateTime? now,
  }) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) {
      return ProofQualityResponseResult.hidden(
        surface: surface,
        source: source,
        entryCount: entries.length,
      );
    }

    final feedbackState = resolveFeedbackState(
      surface: surface,
      proofKey: proofKey,
    );
    if (!_isActionable(feedbackState)) {
      return ProofQualityResponseResult.hidden(
        surface: surface,
        source: source,
        entryCount: entries.length,
      );
    }

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final correction = CorrectionMemoryEngine.build(
      entries: entries,
      source: source,
      now: now,
    );
    final hasFreshReturn = correction?.returnedAfterFaded ?? false;
    final stillTooVague = ProofQualityResponseStore.stillTooVagueFor(
      surface: surface,
      proofKey: proofKey,
    );

    final anchorExtraction = EvidenceAnchorEngine.build(
      entries: entries,
      beliefSurfaceVisible: true,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
      now: now,
    );
    final patternMatchQuality = PatternMatchQualityEngine.build(
      entries: entries,
      beliefSurfaceVisible: true,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
      now: now,
    );
    PatternMatchQualityAnalytics.resolved(result: patternMatchQuality);
    final correctionSnapshot = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final proofConfidenceCalibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: true,
      source: source,
      patternMatchQuality: patternMatchQuality,
      anchorExtraction: anchorExtraction,
      now: now,
      correction: correctionSnapshot,
      trackAnalytics: true,
    );

    return switch (feedbackState) {
      ProofQualityFeedbackState.tooVague => ProofQualityResponseResult(
          shouldShow: true,
          feedbackState: feedbackState,
          surface: surface,
          proofKey: proofKey,
          entryCount: entries.length,
          source: source,
          hasConfirmedRepeat: hasConfirmedRepeat,
          hasSafeAnchor: anchorExtraction.hasSafeAnchor &&
              patternMatchQuality.shouldShowAsProof,
          hasFreshReturn: hasFreshReturn,
          title: ProofQualityResponseCopy.tooVagueTitle,
          body: stillTooVague
              ? ProofQualityResponseCopy.stillTooVagueFollowUp
              : '${proofConfidenceCalibration.primaryCopy}\n\n${ProofQualityResponseCopy.tooVagueBody}',
          footer: ProofQualityResponseCopy.footer,
          rows: ProofQualityResponseCopy.tooVagueRows,
          evidenceAnchors: anchorExtraction.safeSummaries,
          usesFallbackEvidenceLine: anchorExtraction.usesFallback,
          deltaLine: proofConfidenceCalibration.leadCopy,
          returnedAfterCorrectionLine:
              ProofQualityResponseCopy.returnedAfterCorrectionLine,
          stillTooVagueFollowUp: stillTooVague,
        ),
      ProofQualityFeedbackState.alreadyKnewThis => ProofQualityResponseResult(
          shouldShow: true,
          feedbackState: feedbackState,
          surface: surface,
          proofKey: proofKey,
          entryCount: entries.length,
          source: source,
          hasConfirmedRepeat: hasConfirmedRepeat,
          hasSafeAnchor: anchorExtraction.hasSafeAnchor &&
              patternMatchQuality.shouldShowAsProof,
          hasFreshReturn: hasFreshReturn,
          title: ProofQualityResponseCopy.alreadyKnewTitle,
          body:
              '${proofConfidenceCalibration.primaryCopy}\n\n${ProofQualityResponseCopy.alreadyKnewBody}',
          footer: ProofQualityResponseCopy.footer,
          rows: ProofQualityResponseCopy.alreadyKnewRows,
          evidenceAnchors: const [],
          usesFallbackEvidenceLine: false,
          deltaLine: proofConfidenceCalibration.leadCopy ??
              ProofQualityResponseCopy.alreadyKnewDeltaLine,
          returnedAfterCorrectionLine:
              ProofQualityResponseCopy.returnedAfterCorrectionLine,
          stillTooVagueFollowUp: false,
        ),
      ProofQualityFeedbackState.notRelevant => ProofQualityResponseResult(
          shouldShow: true,
          feedbackState: feedbackState,
          surface: surface,
          proofKey: proofKey,
          entryCount: entries.length,
          source: source,
          hasConfirmedRepeat: hasConfirmedRepeat,
          hasSafeAnchor: anchorExtraction.hasSafeAnchor &&
              patternMatchQuality.shouldShowAsProof,
          hasFreshReturn: hasFreshReturn,
          title: ProofQualityResponseCopy.notRelevantTitle,
          body: switch (proofConfidenceCalibration.level) {
            ProofConfidenceLevel.freshReturn ||
            ProofConfidenceLevel.corrected =>
              proofConfidenceCalibration.primaryCopy,
            _ => ProofQualityResponseCopy.notRelevantBody,
          },
          footer: ProofQualityResponseCopy.footer,
          rows: const [],
          evidenceAnchors: const [],
          usesFallbackEvidenceLine: false,
          deltaLine: proofConfidenceCalibration.leadCopy,
          returnedAfterCorrectionLine: hasFreshReturn
              ? proofConfidenceCalibration.primaryCopy
              : ProofQualityResponseCopy.returnedAfterCorrectionLine,
          stillTooVagueFollowUp: false,
        ),
      _ => ProofQualityResponseResult.hidden(
          surface: surface,
          source: source,
          entryCount: entries.length,
        ),
    };
  }

  static ProofQualityFeedbackState resolveFeedbackState({
    required ProofQualityResponseSurface surface,
    required String proofKey,
  }) {
    final betaSurface = betaSurfaceFor(surface);
    final record = BetaProofFeedbackStore.recordFor(betaSurface);
    if (record.answered && record.feedbackType != null) {
      return switch (record.feedbackType!) {
        BetaProofFeedbackType.tooVague => ProofQualityFeedbackState.tooVague,
        BetaProofFeedbackType.alreadyKnew =>
          ProofQualityFeedbackState.alreadyKnewThis,
        BetaProofFeedbackType.notRelevant =>
          ProofQualityFeedbackState.notRelevant,
        BetaProofFeedbackType.useful => ProofQualityFeedbackState.useful,
      };
    }

    if (NotRelevantRecoveryEngine.hasNotRelevantTrigger(proofKey: proofKey)) {
      return ProofQualityFeedbackState.notRelevant;
    }

    return ProofQualityFeedbackState.none;
  }

  static BetaProofFeedbackSurface betaSurfaceFor(
    ProofQualityResponseSurface surface,
  ) =>
      switch (surface) {
        ProofQualityResponseSurface.timelineProofMoment =>
          BetaProofFeedbackSurface.timelineProofMoment,
        ProofQualityResponseSurface.firstProofPayoff =>
          BetaProofFeedbackSurface.firstProofPayoff,
        ProofQualityResponseSurface.patterns =>
          BetaProofFeedbackSurface.timelineProofMoment,
        ProofQualityResponseSurface.archiveTimelineSpine =>
          BetaProofFeedbackSurface.archiveTimelineSpine,
      };

  static bool _isActionable(ProofQualityFeedbackState state) =>
      state == ProofQualityFeedbackState.tooVague ||
      state == ProofQualityFeedbackState.alreadyKnewThis ||
      state == ProofQualityFeedbackState.notRelevant;

  static bool coversLegacyBoost({
    required ProofQualityResponseResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      result.feedbackState == ProofQualityFeedbackState.tooVague &&
      shouldRender(
        result: result,
        parentVisible: parentVisible,
        timelineProofVisible: timelineProofVisible,
        firstProofPayoffVisible: firstProofPayoffVisible,
        isRecording: isRecording,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool coversLegacyNotRelevant({
    required ProofQualityResponseResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      result.feedbackState == ProofQualityFeedbackState.notRelevant &&
      shouldRender(
        result: result,
        parentVisible: parentVisible,
        timelineProofVisible: timelineProofVisible,
        firstProofPayoffVisible: firstProofPayoffVisible,
        isRecording: isRecording,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShow({
    required ProofQualityResponseResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (!result.shouldShow) return false;
    if (!parentVisible) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;

    if (result.feedbackState == ProofQualityFeedbackState.tooVague) {
      if (result.surface == ProofQualityResponseSurface.patterns) {
        return timelineProofVisible;
      }
      if (result.surface == ProofQualityResponseSurface.firstProofPayoff) {
        return firstProofPayoffVisible && result.hasConfirmedRepeat;
      }
      if (timelineProofVisible && result.usesFallbackEvidenceLine) {
        return true;
      }
      return BetaProofFeedbackStore.recordFor(
            betaSurfaceFor(result.surface),
          ).feedbackType ==
          BetaProofFeedbackType.tooVague;
    }

    return true;
  }

  static bool shouldRender({
    required ProofQualityResponseResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (ProofQualityResponseStore.isAnswered(
      surface: result.surface,
      proofKey: result.proofKey,
    )) {
      if (!parentVisible) return false;
      if (isRecording) return false;
      if (isDegradedTranscriptState) return false;
      if (isPostSaveDegradedState) return false;
      if (whatChangedQuestionActive) return false;
      if (patternReviewInboxHasActiveItems) return false;
      return ArchiveBetaMissionGate.isEnabled;
    }
    return shouldShow(
      result: result,
      parentVisible: parentVisible,
      timelineProofVisible: timelineProofVisible,
      firstProofPayoffVisible: firstProofPayoffVisible,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static Future<void> applyStillTooVague({
    required ProofQualityResponseResult result,
    required String source,
    ProofQualityResponseStore? store,
  }) async {
    await (store ?? ProofQualityResponseStore.instance()).saveAnswer(
      surface: result.surface,
      proofKey: result.proofKey,
      answerType: ProofQualityResponseAnswerType.stillTooVague,
      feedbackState: result.feedbackState,
      entryCount: result.entryCount,
      stillTooVague: true,
    );
  }

  static Future<void> applyAlreadyKnewAnswer({
    required ProofQualityResponseResult result,
    required ProofQualityAlreadyKnewAnswer answer,
    required String source,
    ProofQualityResponseStore? store,
  }) async {
    final answerType = _answerTypeForAlreadyKnew(answer);
    await (store ?? ProofQualityResponseStore.instance()).saveAnswer(
      surface: result.surface,
      proofKey: result.proofKey,
      answerType: answerType,
      feedbackState: result.feedbackState,
      entryCount: result.entryCount,
    );
    await syncAlreadyKnewFromAction(
      result: result,
      answer: answer,
      source: source,
    );
  }

  static Future<void> syncAlreadyKnewFromAction({
    required ProofQualityResponseResult result,
    required ProofQualityAlreadyKnewAnswer answer,
    required String source,
  }) async {
    if (answer == ProofQualityAlreadyKnewAnswer.feltLighter) {
      await NotRelevantRecoveryEngine.syncCorrectionFromAction(
        result: _notRelevantResultFrom(result),
        actionType: NotRelevantRecoveryActionType.watchLightly,
        source: source,
      );
    } else if (answer == ProofQualityAlreadyKnewAnswer.cameBackStronger) {
      await NotRelevantRecoveryEngine.syncCorrectionFromAction(
        result: _notRelevantResultFrom(result),
        actionType: NotRelevantRecoveryActionType.relevantAgain,
        source: source,
      );
    } else if (answer == ProofQualityAlreadyKnewAnswer.noChange) {
      await NotRelevantRecoveryEngine.syncCorrectionFromAction(
        result: _notRelevantResultFrom(result),
        actionType: NotRelevantRecoveryActionType.keepAsBackground,
        source: source,
      );
    }
  }

  static Future<void> applyNotRelevantAction({
    required ProofQualityResponseResult result,
    required ProofQualityNotRelevantAction action,
    required String source,
    ProofQualityResponseStore? store,
  }) async {
    await (store ?? ProofQualityResponseStore.instance()).saveAnswer(
      surface: result.surface,
      proofKey: result.proofKey,
      answerType: _answerTypeForNotRelevant(action),
      feedbackState: result.feedbackState,
      entryCount: result.entryCount,
    );
    await syncNotRelevantFromAction(
      result: result,
      action: action,
      source: source,
    );
  }

  static Future<void> syncNotRelevantFromAction({
    required ProofQualityResponseResult result,
    required ProofQualityNotRelevantAction action,
    required String source,
  }) async {
    await NotRelevantRecoveryEngine.applyAction(
      result: _notRelevantResultFrom(result),
      actionType: _recoveryActionFor(action),
      source: source,
    );
  }

  static NotRelevantRecoveryResult _notRelevantResultFrom(
    ProofQualityResponseResult result,
  ) =>
      NotRelevantRecoveryResult(
        shouldShow: true,
        proofKey: result.proofKey,
        entryCount: result.entryCount,
        source: result.source,
        hasConfirmedRepeat: result.hasConfirmedRepeat,
        hasFreshReturn: result.hasFreshReturn,
        title: ProofQualityResponseCopy.notRelevantTitle,
        body: ProofQualityResponseCopy.notRelevantBody,
        correctionLine: ProofQualityResponseCopy.footer,
        returnLine: ProofQualityResponseCopy.returnedAfterCorrectionLine,
        returnedAfterCorrectionLine: result.returnedAfterCorrectionLine,
      );

  static ProofQualityResponseAnswerType _answerTypeForAlreadyKnew(
    ProofQualityAlreadyKnewAnswer answer,
  ) =>
      switch (answer) {
        ProofQualityAlreadyKnewAnswer.cameBackStronger =>
          ProofQualityResponseAnswerType.cameBackStronger,
        ProofQualityAlreadyKnewAnswer.feltLighter =>
          ProofQualityResponseAnswerType.feltLighter,
        ProofQualityAlreadyKnewAnswer.somethingHelped =>
          ProofQualityResponseAnswerType.somethingHelped,
        ProofQualityAlreadyKnewAnswer.noChange =>
          ProofQualityResponseAnswerType.noChange,
      };

  static ProofQualityResponseAnswerType _answerTypeForNotRelevant(
    ProofQualityNotRelevantAction action,
  ) =>
      switch (action) {
        ProofQualityNotRelevantAction.keepAsBackground =>
          ProofQualityResponseAnswerType.keepAsBackground,
        ProofQualityNotRelevantAction.watchLightly =>
          ProofQualityResponseAnswerType.watchLightly,
        ProofQualityNotRelevantAction.relevantAgain =>
          ProofQualityResponseAnswerType.relevantAgain,
      };

  static NotRelevantRecoveryActionType _recoveryActionFor(
    ProofQualityNotRelevantAction action,
  ) =>
      switch (action) {
        ProofQualityNotRelevantAction.keepAsBackground =>
          NotRelevantRecoveryActionType.keepAsBackground,
        ProofQualityNotRelevantAction.watchLightly =>
          NotRelevantRecoveryActionType.watchLightly,
        ProofQualityNotRelevantAction.relevantAgain =>
          NotRelevantRecoveryActionType.relevantAgain,
      };

  static String followUpFor({
    required ProofQualityResponseResult result,
    required ProofQualityResponseRecord record,
  }) {
    final answerType = record.answerType;
    if (answerType == null) return '';

    return switch (result.feedbackState) {
      ProofQualityFeedbackState.tooVague =>
        ProofQualityResponseCopy.stillTooVagueFollowUp,
      ProofQualityFeedbackState.alreadyKnewThis =>
        _alreadyKnewFollowUp(answerType),
      ProofQualityFeedbackState.notRelevant =>
        _notRelevantFollowUp(answerType),
      _ => '',
    };
  }

  static String _alreadyKnewFollowUp(ProofQualityResponseAnswerType answerType) =>
      switch (answerType) {
        ProofQualityResponseAnswerType.cameBackStronger =>
          ProofQualityResponseCopy.cameBackStrongerFollowUp,
        ProofQualityResponseAnswerType.feltLighter =>
          ProofQualityResponseCopy.feltLighterFollowUp,
        ProofQualityResponseAnswerType.somethingHelped =>
          ProofQualityResponseCopy.somethingHelpedFollowUp,
        ProofQualityResponseAnswerType.noChange =>
          ProofQualityResponseCopy.noChangeFollowUp,
        _ => '',
      };

  static String _notRelevantFollowUp(ProofQualityResponseAnswerType answerType) =>
      switch (answerType) {
        ProofQualityResponseAnswerType.keepAsBackground =>
          ProofQualityResponseCopy.keepAsBackgroundFollowUp,
        ProofQualityResponseAnswerType.watchLightly =>
          ProofQualityResponseCopy.watchLightlyFollowUp,
        ProofQualityResponseAnswerType.relevantAgain =>
          ProofQualityResponseCopy.relevantAgainFollowUp,
        _ => '',
      };

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );
}
