import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import 'beta_activation_path_copy.dart';
import 'beta_activation_path_model.dart';
import 'beta_activation_path_store.dart';

/// Beta activation path visibility — lightweight guidance toward paid moment.
abstract final class BetaActivationPathEngine {
  BetaActivationPathEngine._();

  static BetaActivationPathContext buildContext({
    required String source,
    required int entryCount,
    bool? betaMissionEnabled,
    bool dismissedForToday = false,
    bool hasUsefulProof = false,
    bool hasTimelineProof = false,
    bool hasPaywallSeen = false,
    bool hasPurchaseCtaTapped = false,
    bool strongerProCardVisible = false,
    bool isReady = true,
    bool isRecording = false,
    bool isPostSave = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool whatChangedQuestionActive = false,
    bool patternReviewInboxHasActiveItems = false,
    bool isPermissionBlocked = false,
  }) =>
      BetaActivationPathContext(
        source: source,
        entryCount: entryCount,
        betaMissionEnabled: betaMissionEnabled ?? ArchiveBetaMissionGate.isEnabled,
        dismissedForToday:
            dismissedForToday || BetaActivationPathStore.isDismissedToday,
        hasUsefulProof: hasUsefulProof || _hasUsefulFeedbackToday(),
        hasTimelineProof: hasTimelineProof,
        hasPaywallSeen: hasPaywallSeen,
        hasPurchaseCtaTapped: hasPurchaseCtaTapped,
        strongerProCardVisible: strongerProCardVisible,
        isReady: isReady,
        isRecording: isRecording,
        isPostSave: isPostSave,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isPermissionBlocked: isPermissionBlocked,
      );

  static BetaActivationPathResult build({
    required BetaActivationPathContext context,
  }) {
    final stage = _resolveStage(context);
    if (stage == null || stage == BetaActivationPathStage.paidMomentReached) {
      return BetaActivationPathResult(
        shouldShow: false,
        stage: stage ?? BetaActivationPathStage.firstSave,
        slot: BetaActivationPathSlot.hidden,
        title: '',
        body: '',
        primaryCta: '',
        secondaryCta: '',
        primaryActionType: BetaActivationPathActionType.notNow,
        secondaryActionType: BetaActivationPathActionType.notNow,
        source: context.source,
        entryCount: context.entryCount,
        hasUsefulProof: context.hasUsefulProof,
        hasTimelineProof: context.hasTimelineProof,
        hasPaywallSeen: context.hasPaywallSeen,
        diagnosis: BetaActivationPathCopy.diagnosisNeedFirstSave,
      );
    }

    final copy = _copyFor(stage);
    final slot = _slotFor(context, stage);
    final shouldShow = shouldShowCard(context, stage: stage, slot: slot);

    return BetaActivationPathResult(
      shouldShow: shouldShow,
      stage: stage,
      slot: slot,
      title: copy.title,
      body: copy.body,
      primaryCta: copy.primaryCta,
      secondaryCta: copy.secondaryCta,
      primaryActionType: copy.primaryActionType,
      secondaryActionType: copy.secondaryActionType,
      source: context.source,
      entryCount: context.entryCount,
      hasUsefulProof: context.hasUsefulProof,
      hasTimelineProof: context.hasTimelineProof,
      hasPaywallSeen: context.hasPaywallSeen,
      diagnosis: BetaActivationPathCopy.diagnosisFor(stage),
    );
  }

  static bool shouldShowCard(
    BetaActivationPathContext context, {
    BetaActivationPathStage? stage,
    BetaActivationPathSlot? slot,
  }) {
    final resolvedStage = stage ?? _resolveStage(context);
    final resolvedSlot = slot ?? _slotFor(context, resolvedStage);
    if (resolvedStage == null ||
        resolvedStage == BetaActivationPathStage.paidMomentReached ||
        resolvedSlot == BetaActivationPathSlot.hidden) {
      return false;
    }
    if (!context.betaMissionEnabled) return false;
    if (context.dismissedForToday) return false;
    if (!context.isReady) return false;
    if (context.isRecording) return false;
    if (context.isPostSave) return false;
    if (context.isDegradedTranscriptState) return false;
    if (context.isPostSaveDegradedState) return false;
    if (context.whatChangedQuestionActive) return false;
    if (context.patternReviewInboxHasActiveItems) return false;
    if (context.entryCount == 0 && context.isPermissionBlocked) return false;
    if (resolvedStage == BetaActivationPathStage.valueMoment &&
        context.strongerProCardVisible) {
      return false;
    }
    return true;
  }

  static bool suppressesLegacyEarlyGuidance({
    required bool betaActivationPathVisible,
  }) =>
      betaActivationPathVisible;

  static BetaActivationPathStage? _resolveStage(BetaActivationPathContext context) {
    if (context.hasPurchaseCtaTapped) {
      return BetaActivationPathStage.paidMomentReached;
    }
    return switch (context.entryCount) {
      <= 0 => BetaActivationPathStage.firstSave,
      1 => BetaActivationPathStage.secondSave,
      2 => BetaActivationPathStage.thirdSave,
      _ when !context.hasUsefulProof => BetaActivationPathStage.proofCheck,
      _ when context.hasPaywallSeen && !context.hasPurchaseCtaTapped =>
        BetaActivationPathStage.proReview,
      _ when context.strongerProCardVisible => null,
      _ => BetaActivationPathStage.valueMoment,
    };
  }

  static BetaActivationPathSlot _slotFor(
    BetaActivationPathContext context,
    BetaActivationPathStage? stage,
  ) {
    if (stage == null || stage == BetaActivationPathStage.paidMomentReached) {
      return BetaActivationPathSlot.hidden;
    }
    return switch (stage) {
      BetaActivationPathStage.firstSave ||
      BetaActivationPathStage.secondSave ||
      BetaActivationPathStage.thirdSave =>
        BetaActivationPathSlot.guidance,
      BetaActivationPathStage.proofCheck ||
      BetaActivationPathStage.valueMoment ||
      BetaActivationPathStage.proReview =>
        BetaActivationPathSlot.revenue,
      BetaActivationPathStage.paidMomentReached =>
        BetaActivationPathSlot.hidden,
    };
  }

  static _StageCopy _copyFor(BetaActivationPathStage stage) => switch (stage) {
        BetaActivationPathStage.firstSave => _StageCopy(
            title: BetaActivationPathCopy.firstSaveTitle,
            body: BetaActivationPathCopy.firstSaveBody,
            primaryCta: BetaActivationPathCopy.firstSavePrimaryCta,
            secondaryCta: BetaActivationPathCopy.firstSaveSecondaryCta,
            primaryActionType: BetaActivationPathActionType.saveFirstMoment,
            secondaryActionType: BetaActivationPathActionType.notNow,
          ),
        BetaActivationPathStage.secondSave => _StageCopy(
            title: BetaActivationPathCopy.secondSaveTitle,
            body: BetaActivationPathCopy.secondSaveBody,
            primaryCta: BetaActivationPathCopy.secondSavePrimaryCta,
            secondaryCta: BetaActivationPathCopy.secondSaveSecondaryCta,
            primaryActionType: BetaActivationPathActionType.saveAnotherMoment,
            secondaryActionType: BetaActivationPathActionType.notToday,
          ),
        BetaActivationPathStage.thirdSave => _StageCopy(
            title: BetaActivationPathCopy.thirdSaveTitle,
            body: BetaActivationPathCopy.thirdSaveBody,
            primaryCta: BetaActivationPathCopy.thirdSavePrimaryCta,
            secondaryCta: BetaActivationPathCopy.thirdSaveSecondaryCta,
            primaryActionType: BetaActivationPathActionType.saveOneMoreMoment,
            secondaryActionType: BetaActivationPathActionType.notToday,
          ),
        BetaActivationPathStage.proofCheck => _StageCopy(
            title: BetaActivationPathCopy.proofCheckTitle,
            body: BetaActivationPathCopy.proofCheckBody,
            primaryCta: BetaActivationPathCopy.proofCheckPrimaryCta,
            secondaryCta: BetaActivationPathCopy.proofCheckSecondaryCta,
            primaryActionType: BetaActivationPathActionType.viewTimelineProof,
            secondaryActionType: BetaActivationPathActionType.notNow,
          ),
        BetaActivationPathStage.valueMoment => _StageCopy(
            title: BetaActivationPathCopy.valueMomentTitle,
            body: BetaActivationPathCopy.valueMomentBody,
            primaryCta: BetaActivationPathCopy.valueMomentPrimaryCta,
            secondaryCta: BetaActivationPathCopy.valueMomentSecondaryCta,
            primaryActionType: BetaActivationPathActionType.seeWhatProKeeps,
            secondaryActionType: BetaActivationPathActionType.notNow,
          ),
        BetaActivationPathStage.proReview => _StageCopy(
            title: BetaActivationPathCopy.proReviewTitle,
            body: BetaActivationPathCopy.proReviewBody,
            primaryCta: BetaActivationPathCopy.proReviewPrimaryCta,
            secondaryCta: BetaActivationPathCopy.proReviewSecondaryCta,
            primaryActionType: BetaActivationPathActionType.reviewProValue,
            secondaryActionType: BetaActivationPathActionType.notNow,
          ),
        BetaActivationPathStage.paidMomentReached => const _StageCopy(
            title: '',
            body: '',
            primaryCta: '',
            secondaryCta: '',
            primaryActionType: BetaActivationPathActionType.notNow,
            secondaryActionType: BetaActivationPathActionType.notNow,
          ),
      };

  static bool _hasUsefulFeedbackToday() {
    for (final surface in BetaProofFeedbackSurface.values) {
      if (!BetaProofFeedbackStore.isAnsweredToday(surface)) continue;
      final record = BetaProofFeedbackStore.recordFor(surface);
      if (record.feedbackType == BetaProofFeedbackType.useful) {
        return true;
      }
    }
    return false;
  }
}

class _StageCopy {
  const _StageCopy({
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.primaryActionType,
    required this.secondaryActionType,
  });

  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final BetaActivationPathActionType primaryActionType;
  final BetaActivationPathActionType secondaryActionType;
}
