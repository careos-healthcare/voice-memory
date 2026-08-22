import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:archiveme_mobile/features/not_relevant_recovery/not_relevant_recovery_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_timing_loosen_engine.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_analytics.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Central gate for when Pro prompts may appear — after proof, not before value.
abstract final class ProMomentTimingEngine {
  ProMomentTimingEngine._();

  static ProMomentTimingResult evaluate(ProMomentTimingContext context) {
    if (context.isZeroEntryState || context.entryCount <= 0) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.beforeFirstSave,
        reason: 'before_first_save',
      );
    }

    if (context.isFirstRecordingState) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.beforeFirstSave,
        reason: 'before_first_save',
      );
    }

    if (!context.hasFirstProof) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.beforeFirstProof,
        reason: 'before_first_proof',
      );
    }

    if (context.isRecording) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.recording,
        reason: 'recording',
      );
    }

    if (context.isPostSaveDegradedState || context.isDegradedTranscriptState) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.postSaveDegraded,
        reason: 'post_save_degraded',
      );
    }

    if (context.feedbackState == ProofQualityFeedbackState.tooVague) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.feedbackTooVague,
        reason: 'feedback_too_vague',
      );
    }

    if (context.feedbackState == ProofQualityFeedbackState.notRelevant) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.feedbackNotRelevant,
        reason: 'feedback_not_relevant',
      );
    }

    if (context.whatChangedQuestionActive) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.whatChangedActive,
        reason: 'what_changed_active',
      );
    }

    if (context.patternReviewInboxHasActiveItems) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.patternReviewInboxActive,
        reason: 'pattern_review_inbox_active',
      );
    }

    if (!context.proSlotAvailable) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.proSlotAlreadyUsed,
        reason: 'pro_slot_already_used',
      );
    }

    final trigger = ProBridgeTimingLoosenEngine.resolveTriggerForContext(
      context,
    );
    if (trigger == null) {
      return const ProMomentTimingResult.blocked(
        blockedReason: ProMomentTimingBlockedReason.noAllowedMoment,
        reason: 'no_allowed_moment',
      );
    }

    return ProMomentTimingResult.allowed(
      trigger: trigger,
      reason: trigger.analyticsValue,
      hasTimelineProof: context.hasTimelineProofVisible,
    );
  }

  static bool applyGate({
    required bool candidate,
    required ProMomentTimingContext timing,
    bool emitAnalytics = true,
  }) {
    if (!candidate) return false;
    final result = evaluate(timing);
    if (emitAnalytics) {
      _emitAnalytics(context: timing, result: result);
    }
    if (result.allowed) {
      trackSeen(context: timing, result: result);
    }
    return result.allowed;
  }

  static bool allowsProPrompt(
    ProMomentTimingContext context, {
    bool emitAnalytics = false,
  }) {
    final result = evaluate(context);
    if (emitAnalytics) {
      _emitAnalytics(context: context, result: result);
    }
    return result.allowed;
  }

  static void trackSeen({
    required ProMomentTimingContext context,
    required ProMomentTimingResult result,
  }) {
    if (!result.allowed || result.trigger == null) return;
    ProMomentTimingAnalytics.seen(
      source: context.source,
      surface: context.surface.analyticsValue,
      entryCount: context.entryCount,
      reason: result.reason ?? result.trigger!.analyticsValue,
      hasTimelineProof: context.hasTimelineProofVisible,
      feedbackState: context.feedbackState.analyticsValue,
    );
  }

  static ProofQualityFeedbackState resolveFeedbackState({
    required List<JournalEntry> entries,
    required ProofQualityResponseSurface surface,
  }) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) return ProofQualityFeedbackState.none;
    return ProofQualityResponseEngine.resolveFeedbackState(
      surface: surface,
      proofKey: proofKey,
    );
  }

  static ProofQualityFeedbackState resolveFeedbackFromBetaSurface(
    BetaProofFeedbackSurface surface,
  ) {
    final record = BetaProofFeedbackStore.recordFor(surface);
    if (!record.answered || record.feedbackType == null) {
      return ProofQualityFeedbackState.none;
    }
    return switch (record.feedbackType!) {
      BetaProofFeedbackType.useful => ProofQualityFeedbackState.useful,
      BetaProofFeedbackType.tooVague => ProofQualityFeedbackState.tooVague,
      BetaProofFeedbackType.notRelevant =>
        ProofQualityFeedbackState.notRelevant,
      BetaProofFeedbackType.alreadyKnew =>
        ProofQualityFeedbackState.alreadyKnewThis,
    };
  }

  static bool hasNotRelevantFeedback({required List<JournalEntry> entries}) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isEmpty) return false;
    if (NotRelevantRecoveryEngine.hasNotRelevantTrigger(proofKey: proofKey)) {
      return true;
    }
    return resolveFeedbackFromBetaSurface(
              BetaProofFeedbackSurface.timelineProofMoment,
            ) ==
            ProofQualityFeedbackState.notRelevant ||
        resolveFeedbackFromBetaSurface(
              BetaProofFeedbackSurface.firstProofPayoff,
            ) ==
            ProofQualityFeedbackState.notRelevant;
  }

  static void _emitAnalytics({
    required ProMomentTimingContext context,
    required ProMomentTimingResult result,
  }) {
    if (result.allowed) {
      ProMomentTimingAnalytics.allowed(
        source: context.source,
        surface: context.surface.analyticsValue,
        entryCount: context.entryCount,
        reason: result.reason ?? result.trigger!.analyticsValue,
        hasTimelineProof: context.hasTimelineProofVisible,
        feedbackState: context.feedbackState.analyticsValue,
      );
      return;
    }

    ProMomentTimingAnalytics.blocked(
      source: context.source,
      surface: context.surface.analyticsValue,
      entryCount: context.entryCount,
      blockedReason: result.blockedReason!.analyticsValue,
      hasTimelineProof: context.hasTimelineProofVisible,
      feedbackState: context.feedbackState.analyticsValue,
    );
  }
}