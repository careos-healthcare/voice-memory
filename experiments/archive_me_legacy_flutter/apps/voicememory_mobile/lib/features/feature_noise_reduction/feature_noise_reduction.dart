import 'feature_noise_reduction_copy.dart';

/// Feature noise reduction — visibility guardrail for the first proof journey.
abstract final class FeatureNoiseReduction {
  FeatureNoiseReduction._();

  static FeatureNoiseReductionResult build(FeatureNoiseReductionInput input) {
    switch (input.surfaceType) {
      case FeatureSurfaceType.recordCapture:
        return _show(FeatureNoiseReductionReason.showCoreCapture);
      case FeatureSurfaceType.debugReadiness:
        if (input.storeReadinessMode) {
          return _show(FeatureNoiseReductionReason.showStoreReadinessDebug);
        }
        return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
      case FeatureSurfaceType.firstProof:
      case FeatureSurfaceType.whyProofAppeared:
      case FeatureSurfaceType.confirmCorrect:
        if (input.hasFirstUsefulProof) {
          return _show(FeatureNoiseReductionReason.showFirstProofJourney);
        }
        return _hide(FeatureNoiseReductionReason.hideBeforeFirstProof);
      case FeatureSurfaceType.promptAssist:
        if (input.isRecordScreen || input.isPostSave) {
          return _show(FeatureNoiseReductionReason.showPromptAssist);
        }
        return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
      case FeatureSurfaceType.positiveReinforcement:
        if (input.isPostSave) {
          return _show(FeatureNoiseReductionReason.showPositiveReinforcement);
        }
        return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
      case FeatureSurfaceType.longerTrail:
        if (input.hasConfirmedRepeat || input.hasLongerTrail) {
          return _show(FeatureNoiseReductionReason.showLongerTrail);
        }
        return _hide(FeatureNoiseReductionReason.hideBeforeLongerTrail);
      case FeatureSurfaceType.proTrail:
        if (input.hasFirstUsefulProof || input.hasLongerTrail) {
          return _show(FeatureNoiseReductionReason.showProTrail);
        }
        return _hide(FeatureNoiseReductionReason.hideBeforeFirstProof);
      case FeatureSurfaceType.contextDetail:
        return _evaluateContextDetail(input);
      case FeatureSurfaceType.archiveHealth:
        return _evaluateArchiveHealth(input);
      case FeatureSurfaceType.actionItems:
        return _evaluateActionItems(input);
      case FeatureSurfaceType.quickActions:
        return _evaluateQuickActions(input);
      case FeatureSurfaceType.weeklyReport:
      case FeatureSurfaceType.monthlyReport:
      case FeatureSurfaceType.privateReport:
        return _evaluateReports(input);
      case FeatureSurfaceType.archiveReview:
        return _evaluateArchiveReview(input);
      case FeatureSurfaceType.workspaceHint:
        return _evaluateWorkspaceHint(input);
      case FeatureSurfaceType.acquisitionWedge:
      case FeatureSurfaceType.export:
        return _evaluateGenericSecondary(input);
    }
  }

  static FeatureNoiseReductionReport report(
    FeatureNoiseReductionResult result,
  ) => FeatureNoiseReductionReport(
    headline: FeatureNoiseReductionCopy.headline,
    body: FeatureNoiseReductionCopy.body,
    coreJourneyLine: FeatureNoiseReductionCopy.coreJourneyLine,
    hideEarlyLine: FeatureNoiseReductionCopy.hideEarlyLine,
    notDeletedLine: FeatureNoiseReductionCopy.notDeletedLine,
    lowEffortLine: FeatureNoiseReductionCopy.lowEffortLine,
    proLine: FeatureNoiseReductionCopy.proLine,
    guardrail: FeatureNoiseReductionCopy.guardrail,
    result: result,
  );

  static FeatureNoiseReductionResult _evaluateContextDetail(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input)) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (input.eligibleEntryCount < 3 || !input.hasFirstUsefulProof) {
      return _hide(FeatureNoiseReductionReason.hideContextUntilEvidence);
    }
    return _show(FeatureNoiseReductionReason.showWhenUserAsked);
  }

  static FeatureNoiseReductionResult _evaluateArchiveHealth(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input)) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (input.eligibleEntryCount < 5) {
      return _hide(FeatureNoiseReductionReason.hideArchiveHealthUntilEvidence);
    }
    return _show(FeatureNoiseReductionReason.showWhenUserAsked);
  }

  static FeatureNoiseReductionResult _evaluateActionItems(
    FeatureNoiseReductionInput input,
  ) {
    if (input.userAskedForSurface) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    return _hide(FeatureNoiseReductionReason.hideActionItemsUntilUserIntent);
  }

  static FeatureNoiseReductionResult _evaluateQuickActions(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input)) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (input.eligibleEntryCount < 5 || !input.hasFirstUsefulProof) {
      return _hide(FeatureNoiseReductionReason.hideQuickActionsUntilEvidence);
    }
    return _show(FeatureNoiseReductionReason.showWhenUserAsked);
  }

  static FeatureNoiseReductionResult _evaluateReports(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input) && input.hasLongerTrail) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (!input.hasLongerTrail) {
      return _hide(FeatureNoiseReductionReason.hideReportsUntilEvidence);
    }
    return _show(FeatureNoiseReductionReason.showWhenUserAsked);
  }

  static FeatureNoiseReductionResult _evaluateArchiveReview(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input)) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (input.eligibleEntryCount < 5 || !input.hasFirstUsefulProof) {
      return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
    }
    return _show(FeatureNoiseReductionReason.showWhenUserAsked);
  }

  static FeatureNoiseReductionResult _evaluateWorkspaceHint(
    FeatureNoiseReductionInput input,
  ) {
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    if (input.hasFirstUsefulProof && !input.hasLongerTrail) {
      return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
    }
    return _evaluateGenericSecondary(input);
  }

  static FeatureNoiseReductionResult _evaluateGenericSecondary(
    FeatureNoiseReductionInput input,
  ) {
    if (_userAskedWithEvidence(input)) {
      return _show(FeatureNoiseReductionReason.showWhenUserAsked);
    }
    if (input.isFirstSession) {
      return _hide(FeatureNoiseReductionReason.hideFirstSessionNoise);
    }
    if (input.isRecordScreen) {
      return _hide(FeatureNoiseReductionReason.hideRecordScreenNoise);
    }
    return _hide(FeatureNoiseReductionReason.hideSecondarySurface);
  }

  static bool _userAskedWithEvidence(FeatureNoiseReductionInput input) =>
      input.userAskedForSurface && input.eligibleEntryCount >= 3;

  static FeatureNoiseReductionResult _show(
    FeatureNoiseReductionReason reason,
  ) => FeatureNoiseReductionResult(shouldShow: true, reason: reason);

  static FeatureNoiseReductionResult _hide(
    FeatureNoiseReductionReason reason,
  ) => FeatureNoiseReductionResult(shouldShow: false, reason: reason);
}

enum FeatureSurfaceType {
  recordCapture,
  firstProof,
  whyProofAppeared,
  confirmCorrect,
  longerTrail,
  proTrail,
  promptAssist,
  positiveReinforcement,
  contextDetail,
  archiveHealth,
  actionItems,
  quickActions,
  weeklyReport,
  monthlyReport,
  privateReport,
  archiveReview,
  workspaceHint,
  acquisitionWedge,
  export,
  debugReadiness,
}

enum FeatureNoiseReductionReason {
  showCoreCapture,
  showFirstProofJourney,
  showPromptAssist,
  showPositiveReinforcement,
  showLongerTrail,
  showProTrail,
  showWhenUserAsked,
  showStoreReadinessDebug,
  hideFirstSessionNoise,
  hideRecordScreenNoise,
  hideBeforeFirstProof,
  hideBeforeLongerTrail,
  hideSecondarySurface,
  hideReportsUntilEvidence,
  hideActionItemsUntilUserIntent,
  hideContextUntilEvidence,
  hideArchiveHealthUntilEvidence,
  hideQuickActionsUntilEvidence,
}

class FeatureNoiseReductionInput {
  const FeatureNoiseReductionInput({
    required this.surfaceType,
    required this.eligibleEntryCount,
    required this.hasFirstUsefulProof,
    required this.hasConfirmedRepeat,
    required this.hasLongerTrail,
    required this.hasUserCorrection,
    required this.isFirstSession,
    required this.isRecordScreen,
    required this.isPostSave,
    required this.userAskedForSurface,
    required this.storeReadinessMode,
  });

  final FeatureSurfaceType surfaceType;
  final int eligibleEntryCount;
  final bool hasFirstUsefulProof;
  final bool hasConfirmedRepeat;
  final bool hasLongerTrail;
  final bool hasUserCorrection;
  final bool isFirstSession;
  final bool isRecordScreen;
  final bool isPostSave;
  final bool userAskedForSurface;
  final bool storeReadinessMode;
}

class FeatureNoiseReductionResult {
  const FeatureNoiseReductionResult({
    required this.shouldShow,
    required this.reason,
  });

  final bool shouldShow;
  final FeatureNoiseReductionReason reason;
}

class FeatureNoiseReductionReport {
  const FeatureNoiseReductionReport({
    required this.headline,
    required this.body,
    required this.coreJourneyLine,
    required this.hideEarlyLine,
    required this.notDeletedLine,
    required this.lowEffortLine,
    required this.proLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String coreJourneyLine;
  final String hideEarlyLine;
  final String notDeletedLine;
  final String lowEffortLine;
  final String proLine;
  final String guardrail;
  final FeatureNoiseReductionResult result;
}
