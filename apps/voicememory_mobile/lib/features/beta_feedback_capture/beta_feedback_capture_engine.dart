import '../beta/archive_beta_mission_gate.dart';
import '../beta_proof_feedback/beta_proof_feedback_engine.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import 'beta_feedback_capture_copy.dart';
import 'beta_feedback_capture_model.dart';
import 'beta_feedback_capture_store.dart';

/// Beta feedback capture visibility — one moment per surface.
abstract final class BetaFeedbackCaptureEngine {
  BetaFeedbackCaptureEngine._();

  static const momentPriority = <BetaFeedbackCaptureMoment>[
    BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase,
    BetaFeedbackCaptureMoment.afterPaywallSeenNoCta,
    BetaFeedbackCaptureMoment.afterProPreview,
    BetaFeedbackCaptureMoment.afterTimelineProof,
    BetaFeedbackCaptureMoment.afterThirdSave,
    BetaFeedbackCaptureMoment.afterFirstSave,
  ];

  static BetaFeedbackCaptureContext buildContext({
    required BetaFeedbackCaptureSurface surface,
    required String source,
    required int entryCount,
    bool? betaMissionEnabled,
    bool isReady = true,
    bool isRecording = false,
    bool isPostSave = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool whatChangedQuestionActive = false,
    bool patternReviewInboxHasActiveItems = false,
    bool hasUsefulProof = false,
    bool hasPaywallSeen = false,
    bool hasPurchaseCtaTapped = false,
    bool isPro = false,
    bool timelineProofVisible = false,
    bool proPreviewVisible = false,
    bool existingProofFeedbackVisible = false,
    bool coreCaptureCtaVisible = false,
    bool paywallNoCtaRequested = false,
    bool paywallPurchaseAttempted = false,
  }) =>
      BetaFeedbackCaptureContext(
        surface: surface,
        source: source,
        entryCount: entryCount,
        betaMissionEnabled: betaMissionEnabled ?? ArchiveBetaMissionGate.isEnabled,
        isReady: isReady,
        isRecording: isRecording,
        isPostSave: isPostSave,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        hasUsefulProof: hasUsefulProof,
        hasPaywallSeen: hasPaywallSeen,
        hasPurchaseCtaTapped: hasPurchaseCtaTapped,
        isPro: isPro,
        timelineProofVisible: timelineProofVisible,
        proPreviewVisible: proPreviewVisible,
        existingProofFeedbackVisible: existingProofFeedbackVisible,
        coreCaptureCtaVisible: coreCaptureCtaVisible,
        paywallNoCtaRequested: paywallNoCtaRequested,
        paywallPurchaseAttempted: paywallPurchaseAttempted,
      );

  static BetaFeedbackCaptureResult build({
    required BetaFeedbackCaptureContext context,
  }) {
    final moment = _resolveMoment(context);
    if (moment == null) {
      return BetaFeedbackCaptureResult.hidden.copyWith(
        source: context.source,
        surface: context.surface,
        entryCount: context.entryCount,
        hasUsefulProof: context.hasUsefulProof,
        hasPaywallSeen: context.hasPaywallSeen,
        hasPurchaseCtaTapped: context.hasPurchaseCtaTapped,
        unresolvedRevenueQuestion: unresolvedRevenueQuestion(context: context),
      );
    }

    final shouldShow = shouldShowCard(context, moment: moment);
    return BetaFeedbackCaptureResult(
      shouldShow: shouldShow,
      moment: moment,
      title: BetaFeedbackCaptureCopy.titleFor(moment),
      options: BetaFeedbackCaptureCopy.optionsFor(moment),
      followUpPlaceholder: BetaFeedbackCaptureCopy.followUpPlaceholderFor(moment),
      source: context.source,
      surface: context.surface,
      entryCount: context.entryCount,
      hasUsefulProof: context.hasUsefulProof,
      hasPaywallSeen: context.hasPaywallSeen,
      hasPurchaseCtaTapped: context.hasPurchaseCtaTapped,
      unresolvedRevenueQuestion: BetaFeedbackCaptureCopy.unresolvedRevenueQuestion(
        moment: moment,
      ),
    );
  }

  static String unresolvedRevenueQuestion({
    required BetaFeedbackCaptureContext context,
  }) {
    final active = _resolveMoment(context);
    if (active != null && !BetaFeedbackCaptureStore.isResolvedToday(active)) {
      return BetaFeedbackCaptureCopy.unresolvedRevenueQuestion(moment: active);
    }
    for (final moment in momentPriority) {
      if (momentEligible(context: context, moment: moment) &&
          !BetaFeedbackCaptureStore.isResolvedToday(moment)) {
        return BetaFeedbackCaptureCopy.unresolvedRevenueQuestion(moment: moment);
      }
    }
    return BetaFeedbackCaptureCopy.unresolvedRevenueQuestion(moment: null);
  }

  static bool shouldShowCard(
    BetaFeedbackCaptureContext context, {
    BetaFeedbackCaptureMoment? moment,
  }) {
    final resolved = moment ?? _resolveMoment(context);
    if (resolved == null) return false;
    if (!context.betaMissionEnabled) return false;
    if (!context.isReady) return false;
    if (context.isRecording) return false;
    if (context.isDegradedTranscriptState) return false;
    if (context.isPostSaveDegradedState) return false;
    if (context.whatChangedQuestionActive) return false;
    if (context.patternReviewInboxHasActiveItems) return false;
    if (context.coreCaptureCtaVisible) return false;
    if (BetaFeedbackCaptureStore.isResolvedToday(resolved)) return false;
    return momentEligible(context: context, moment: resolved);
  }

  static bool momentEligible({
    required BetaFeedbackCaptureContext context,
    required BetaFeedbackCaptureMoment moment,
  }) {
    switch (moment) {
      case BetaFeedbackCaptureMoment.afterFirstSave:
        return context.isPostSave && context.entryCount == 1;
      case BetaFeedbackCaptureMoment.afterThirdSave:
        return context.isPostSave && context.entryCount == 3;
      case BetaFeedbackCaptureMoment.afterTimelineProof:
        return context.timelineProofVisible &&
            !context.existingProofFeedbackVisible;
      case BetaFeedbackCaptureMoment.afterProPreview:
        return context.proPreviewVisible;
      case BetaFeedbackCaptureMoment.afterPaywallSeenNoCta:
        if (context.isPro) return false;
        if (context.surface == BetaFeedbackCaptureSurface.paywall) {
          return context.paywallNoCtaRequested &&
              !context.paywallPurchaseAttempted;
        }
        return context.hasPaywallSeen && !context.hasPurchaseCtaTapped;
      case BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase:
        if (context.isPro) return false;
        if (context.surface == BetaFeedbackCaptureSurface.paywall) {
          return context.paywallPurchaseAttempted;
        }
        return context.hasPurchaseCtaTapped;
    }
  }

  static BetaFeedbackCaptureMoment? _resolveMoment(
    BetaFeedbackCaptureContext context,
  ) {
    for (final moment in momentPriority) {
      if (!momentEligible(context: context, moment: moment)) continue;
      if (BetaFeedbackCaptureStore.isResolvedToday(moment)) continue;
      if (_surfaceAllowsMoment(context.surface, moment)) {
        return moment;
      }
    }
    return null;
  }

  static bool _surfaceAllowsMoment(
    BetaFeedbackCaptureSurface surface,
    BetaFeedbackCaptureMoment moment,
  ) {
    return switch (surface) {
      BetaFeedbackCaptureSurface.recordPostSave =>
        moment == BetaFeedbackCaptureMoment.afterFirstSave ||
            moment == BetaFeedbackCaptureMoment.afterThirdSave ||
            moment == BetaFeedbackCaptureMoment.afterTimelineProof ||
            moment == BetaFeedbackCaptureMoment.afterProPreview,
      BetaFeedbackCaptureSurface.recordReady =>
        moment == BetaFeedbackCaptureMoment.afterTimelineProof ||
            moment == BetaFeedbackCaptureMoment.afterPaywallSeenNoCta ||
            moment == BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase,
      BetaFeedbackCaptureSurface.patterns =>
        moment == BetaFeedbackCaptureMoment.afterTimelineProof ||
            moment == BetaFeedbackCaptureMoment.afterProPreview,
      BetaFeedbackCaptureSurface.paywall =>
        moment == BetaFeedbackCaptureMoment.afterPaywallSeenNoCta ||
            moment == BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase,
    };
  }

  static BetaProofFeedbackType? proofFeedbackTypeForAnswer(String answerId) =>
      switch (answerId) {
        'useful' => BetaProofFeedbackType.useful,
        'too_vague' => BetaProofFeedbackType.tooVague,
        'already_knew' => BetaProofFeedbackType.alreadyKnew,
        'not_relevant' => BetaProofFeedbackType.notRelevant,
        _ => null,
      };

  static bool existingProofFeedbackVisible({
    required BetaProofFeedbackSurface surface,
    required bool parentVisible,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      BetaProofFeedbackEngine.shouldShow(
        surface: surface,
        parentVisible: parentVisible,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );
}

extension BetaFeedbackCaptureResultCopy on BetaFeedbackCaptureResult {
  BetaFeedbackCaptureResult copyWith({
    bool? shouldShow,
    BetaFeedbackCaptureMoment? moment,
    String? title,
    List<BetaFeedbackCaptureOption>? options,
    String? followUpPlaceholder,
    String? source,
    BetaFeedbackCaptureSurface? surface,
    int? entryCount,
    bool? hasUsefulProof,
    bool? hasPaywallSeen,
    bool? hasPurchaseCtaTapped,
    String? unresolvedRevenueQuestion,
  }) =>
      BetaFeedbackCaptureResult(
        shouldShow: shouldShow ?? this.shouldShow,
        moment: moment ?? this.moment,
        title: title ?? this.title,
        options: options ?? this.options,
        followUpPlaceholder: followUpPlaceholder,
        source: source ?? this.source,
        surface: surface ?? this.surface,
        entryCount: entryCount ?? this.entryCount,
        hasUsefulProof: hasUsefulProof ?? this.hasUsefulProof,
        hasPaywallSeen: hasPaywallSeen ?? this.hasPaywallSeen,
        hasPurchaseCtaTapped:
            hasPurchaseCtaTapped ?? this.hasPurchaseCtaTapped,
        unresolvedRevenueQuestion:
            unresolvedRevenueQuestion ?? this.unresolvedRevenueQuestion,
      );
}
