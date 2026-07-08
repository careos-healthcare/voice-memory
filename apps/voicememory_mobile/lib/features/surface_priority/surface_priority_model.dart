/// Surfaces audited for card clutter.
enum SurfacePrioritySurface {
  recordReady,
  recordPostSave,
  patterns,
  weeklyReview,
  paywall,
}

/// Stable keys for cards managed by the priority audit.
enum SurfacePriorityCardKey {
  threeMomentCompletion,
  firstMomentCapture,
  secondMomentReturn,
  returnAfterProofStrengthened,
  returnAfterProofLiftV2,
  returnAfterProof,
  lowFrictionReturn,
  whatToNoticeNext,
  betaTodaySummary,
  openCapturePromptChips,
  captureFreedomLine,
  firstSessionProofRepair,
  firstSessionLift,
  firstSaveLift,
  betaActivationPath,
  betaActivationPathRevenue,
  firstRunPositioning,
  archiveBeliefSurface,
  timelineProofMoment,
  archiveTimelineSpine,
  timelinePositioning,
  currentRelevance,
  correctionMemory,
  notRelevantRecovery,
  proofQualityResponse,
  betaProofLift,
  evidenceWeighting,
  proofSpecificity,
  presentDayRelevance,
  patternConfidence,
  betaTesterReport,
  betaProofFeedback,
  proofQualityRepair,
  betaInviteLoop,
  betaFeedbackCapture,
  firstProofPayoff,
  whatChanged,
  returnPayoff,
  timelineProofMomentPostSave,
  proofSpecificityPostSave,
  proBridgeVisibility,
  proUnderstandingLift,
  proVisibilityLift,
  proPreview,
  proEvidenceValue,
  archiveIntelligenceProBridge,
  proLockMoment,
  privateReportProBridge,
  archiveBackupBridge,
  paywallPrimaryReason,
  paywallSecondaryReason,
  paywallCtaLift,
}

/// Raw candidate visibility before priority caps.
class SurfacePriorityCandidates {
  const SurfacePriorityCandidates(this.byKey);

  final Map<SurfacePriorityCardKey, bool> byKey;

  bool candidate(SurfacePriorityCardKey key) => byKey[key] ?? false;

  factory SurfacePriorityCandidates.recordReady({
    bool threeMomentCompletion = false,
    required bool firstMomentCapture,
    required bool secondMomentReturn,
    bool returnAfterProofStrengthened = false,
    bool returnAfterProof = false,
    required bool lowFrictionReturn,
    required bool whatToNoticeNext,
    required bool betaTodaySummary,
    required bool openCapturePromptChips,
    required bool captureFreedomLine,
    bool betaActivationPath = false,
    bool betaActivationPathRevenue = false,
    bool firstSessionProofRepair = false,
    bool firstSessionLift = false,
    bool firstSaveLift = false,
    bool returnAfterProofLiftV2 = false,
    bool firstRunPositioning = false,
    required bool timelineProofMoment,
    required bool archiveTimelineSpine,
    required bool timelinePositioning,
    required bool currentRelevance,
    required bool correctionMemory,
    required bool notRelevantRecovery,
    required bool proofQualityResponse,
    bool betaProofLift = false,
    bool proofQualityRepair = false,
    required bool evidenceWeighting,
    required bool proofSpecificity,
    required bool presentDayRelevance,
    required bool patternConfidence,
    required bool betaTesterReport,
    bool proBridgeVisibility = false,
    bool proPreview = false,
    bool proUnderstandingLift = false,
    bool proVisibilityLift = false,
    required bool proEvidenceValue,
    required bool privateReportProBridge,
    required bool suppressLegacyEducation,
    bool betaFeedbackCapture = false,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.threeMomentCompletion: threeMomentCompletion,
        SurfacePriorityCardKey.firstMomentCapture: firstMomentCapture,
        SurfacePriorityCardKey.secondMomentReturn: secondMomentReturn,
        SurfacePriorityCardKey.returnAfterProofStrengthened:
            returnAfterProofStrengthened,
        SurfacePriorityCardKey.returnAfterProofLiftV2: returnAfterProofLiftV2,
        SurfacePriorityCardKey.returnAfterProof: returnAfterProof,
        SurfacePriorityCardKey.lowFrictionReturn: lowFrictionReturn,
        SurfacePriorityCardKey.whatToNoticeNext: whatToNoticeNext,
        SurfacePriorityCardKey.betaTodaySummary: betaTodaySummary,
        SurfacePriorityCardKey.openCapturePromptChips: openCapturePromptChips,
        SurfacePriorityCardKey.captureFreedomLine: captureFreedomLine,
        SurfacePriorityCardKey.firstSessionProofRepair: firstSessionProofRepair,
        SurfacePriorityCardKey.firstSessionLift: firstSessionLift,
        SurfacePriorityCardKey.firstSaveLift: firstSaveLift,
        SurfacePriorityCardKey.betaActivationPath: betaActivationPath,
        SurfacePriorityCardKey.betaActivationPathRevenue:
            betaActivationPathRevenue,
        SurfacePriorityCardKey.firstRunPositioning: firstRunPositioning,
        SurfacePriorityCardKey.timelineProofMoment: timelineProofMoment,
        SurfacePriorityCardKey.archiveTimelineSpine: archiveTimelineSpine,
        SurfacePriorityCardKey.timelinePositioning:
            timelinePositioning && !suppressLegacyEducation,
        SurfacePriorityCardKey.currentRelevance:
            currentRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.correctionMemory:
            correctionMemory && !suppressLegacyEducation,
        SurfacePriorityCardKey.notRelevantRecovery: notRelevantRecovery,
        SurfacePriorityCardKey.proofQualityResponse: proofQualityResponse,
        SurfacePriorityCardKey.betaProofLift: betaProofLift,
        SurfacePriorityCardKey.proofQualityRepair: proofQualityRepair,
        SurfacePriorityCardKey.evidenceWeighting:
            evidenceWeighting && !suppressLegacyEducation,
        SurfacePriorityCardKey.proofSpecificity:
            proofSpecificity && !suppressLegacyEducation,
        SurfacePriorityCardKey.presentDayRelevance:
            presentDayRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.patternConfidence:
            patternConfidence && !suppressLegacyEducation,
        SurfacePriorityCardKey.betaTesterReport: betaTesterReport,
        SurfacePriorityCardKey.proBridgeVisibility: proBridgeVisibility,
        SurfacePriorityCardKey.proUnderstandingLift: proUnderstandingLift,
        SurfacePriorityCardKey.proVisibilityLift: proVisibilityLift,
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
        SurfacePriorityCardKey.betaFeedbackCapture: betaFeedbackCapture,
      });

  factory SurfacePriorityCandidates.recordPostSave({
    required bool lowFrictionReturn,
    required bool whatToNoticeNext,
    required bool betaTodaySummary,
    required bool openCapturePromptChips,
    required bool captureFreedomLine,
    required bool firstProofPayoff,
    required bool whatChanged,
    required bool returnPayoff,
    required bool timelineProofMomentPostSave,
    required bool proofSpecificityPostSave,
    required bool betaProofFeedback,
    bool betaInviteLoop = false,
    bool betaFeedbackCapture = false,
    bool betaProofLift = false,
    bool returnAfterProofStrengthened = false,
    bool returnAfterProof = false,
    bool returnAfterProofLiftV2 = false,
    bool proBridgeVisibility = false,
    bool proPreview = false,
    bool proUnderstandingLift = false,
    bool proVisibilityLift = false,
    required bool proEvidenceValue,
    required bool proLockMoment,
    required bool privateReportProBridge,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.lowFrictionReturn: lowFrictionReturn,
        SurfacePriorityCardKey.whatToNoticeNext: whatToNoticeNext,
        SurfacePriorityCardKey.betaTodaySummary: betaTodaySummary,
        SurfacePriorityCardKey.openCapturePromptChips: openCapturePromptChips,
        SurfacePriorityCardKey.captureFreedomLine: captureFreedomLine,
        SurfacePriorityCardKey.firstProofPayoff: firstProofPayoff,
        SurfacePriorityCardKey.whatChanged: whatChanged,
        SurfacePriorityCardKey.returnPayoff: returnPayoff,
        SurfacePriorityCardKey.timelineProofMomentPostSave:
            timelineProofMomentPostSave,
        SurfacePriorityCardKey.proofSpecificityPostSave:
            proofSpecificityPostSave,
        SurfacePriorityCardKey.betaProofFeedback: betaProofFeedback,
        SurfacePriorityCardKey.betaInviteLoop: betaInviteLoop,
        SurfacePriorityCardKey.betaProofLift: betaProofLift,
        SurfacePriorityCardKey.returnAfterProofStrengthened:
            returnAfterProofStrengthened,
        SurfacePriorityCardKey.returnAfterProofLiftV2: returnAfterProofLiftV2,
        SurfacePriorityCardKey.returnAfterProof: returnAfterProof,
        SurfacePriorityCardKey.proBridgeVisibility: proBridgeVisibility,
        SurfacePriorityCardKey.proPreview: proPreview,
        SurfacePriorityCardKey.proUnderstandingLift: proUnderstandingLift,
        SurfacePriorityCardKey.proVisibilityLift: proVisibilityLift,
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.proLockMoment: proLockMoment,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
        SurfacePriorityCardKey.betaFeedbackCapture: betaFeedbackCapture,
      });

  factory SurfacePriorityCandidates.patterns({
    required bool archiveBeliefSurface,
    required bool timelineProofMoment,
    required bool archiveTimelineSpine,
    required bool betaTesterReport,
    required bool correctionMemory,
    required bool notRelevantRecovery,
    required bool proofQualityResponse,
    bool betaProofLift = false,
    required bool patternConfidence,
    required bool evidenceWeighting,
    required bool currentRelevance,
    required bool proofSpecificity,
    required bool presentDayRelevance,
    required bool timelinePositioning,
    bool proBridgeVisibility = false,
    bool proPreview = false,
    bool proUnderstandingLift = false,
    bool proVisibilityLift = false,
    bool betaInviteLoop = false,
    bool betaFeedbackCapture = false,
    required bool proEvidenceValue,
    required bool archiveIntelligenceProBridge,
    required bool privateReportProBridge,
    required bool archiveBackupBridge,
    required bool suppressLegacyEducation,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.archiveBeliefSurface: archiveBeliefSurface,
        SurfacePriorityCardKey.timelineProofMoment: timelineProofMoment,
        SurfacePriorityCardKey.archiveTimelineSpine: archiveTimelineSpine,
        SurfacePriorityCardKey.betaTesterReport: betaTesterReport,
        SurfacePriorityCardKey.correctionMemory:
            correctionMemory && !suppressLegacyEducation,
        SurfacePriorityCardKey.notRelevantRecovery: notRelevantRecovery,
        SurfacePriorityCardKey.proofQualityResponse: proofQualityResponse,
        SurfacePriorityCardKey.betaProofLift: betaProofLift,
        SurfacePriorityCardKey.patternConfidence:
            patternConfidence && !suppressLegacyEducation,
        SurfacePriorityCardKey.evidenceWeighting:
            evidenceWeighting && !suppressLegacyEducation,
        SurfacePriorityCardKey.currentRelevance:
            currentRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.proofSpecificity:
            proofSpecificity && !suppressLegacyEducation,
        SurfacePriorityCardKey.presentDayRelevance:
            presentDayRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.timelinePositioning:
            timelinePositioning && !suppressLegacyEducation,
        SurfacePriorityCardKey.proBridgeVisibility: proBridgeVisibility,
        SurfacePriorityCardKey.proPreview: proPreview,
        SurfacePriorityCardKey.proUnderstandingLift: proUnderstandingLift,
        SurfacePriorityCardKey.proVisibilityLift: proVisibilityLift,
        SurfacePriorityCardKey.betaInviteLoop: betaInviteLoop,
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.archiveIntelligenceProBridge:
            archiveIntelligenceProBridge,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
        SurfacePriorityCardKey.archiveBackupBridge: archiveBackupBridge,
        SurfacePriorityCardKey.betaFeedbackCapture: betaFeedbackCapture,
      });

  factory SurfacePriorityCandidates.paywall({
    required bool primaryReason,
    required bool secondaryReason,
    bool paywallCtaLift = false,
    bool betaFeedbackCapture = false,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.paywallPrimaryReason: primaryReason,
        SurfacePriorityCardKey.paywallSecondaryReason: secondaryReason,
        SurfacePriorityCardKey.paywallCtaLift: paywallCtaLift,
        SurfacePriorityCardKey.betaFeedbackCapture: betaFeedbackCapture,
      });
}

/// Priority audit result for one surface.
class SurfacePriorityResult {
  const SurfacePriorityResult({
    required this.surface,
    required this.entryCount,
    required this.source,
    required this.captureSlot,
    required this.guidanceSlot,
    required this.proofSlot,
    required this.correctionSlot,
    required this.reportSlot,
    required this.proSlot,
    required this.hiddenReasons,
    required this.visibleCardKeys,
    required this.shouldShowDebugSummary,
    required this.suppressedCardCount,
  });

  final SurfacePrioritySurface surface;
  final int entryCount;
  final String source;
  final SurfacePriorityCardKey? captureSlot;
  final SurfacePriorityCardKey? guidanceSlot;
  final SurfacePriorityCardKey? proofSlot;
  final SurfacePriorityCardKey? correctionSlot;
  final SurfacePriorityCardKey? reportSlot;
  final SurfacePriorityCardKey? proSlot;
  final List<String> hiddenReasons;
  final List<SurfacePriorityCardKey> visibleCardKeys;
  final bool shouldShowDebugSummary;
  final int suppressedCardCount;

  int get visibleCardCount => visibleCardKeys.length;

  String? get proofCardKey => proofSlot?.name;

  String? get guidanceCardKey => guidanceSlot?.name;

  bool isVisible(SurfacePriorityCardKey key, {required bool candidate}) =>
      candidate && visibleCardKeys.contains(key);

  bool wasCandidate(
    SurfacePriorityCardKey key,
    SurfacePriorityCandidates candidates,
  ) =>
      candidates.candidate(key);
}
