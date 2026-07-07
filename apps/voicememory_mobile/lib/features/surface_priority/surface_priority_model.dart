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
  firstMomentCapture,
  secondMomentReturn,
  lowFrictionReturn,
  whatToNoticeNext,
  betaTodaySummary,
  openCapturePromptChips,
  captureFreedomLine,
  archiveBeliefSurface,
  timelineProofMoment,
  archiveTimelineSpine,
  timelinePositioning,
  currentRelevance,
  correctionMemory,
  notRelevantRecovery,
  evidenceWeighting,
  proofSpecificity,
  presentDayRelevance,
  patternConfidence,
  betaTesterReport,
  betaProofFeedback,
  firstProofPayoff,
  whatChanged,
  returnPayoff,
  timelineProofMomentPostSave,
  proofSpecificityPostSave,
  proEvidenceValue,
  archiveIntelligenceProBridge,
  proLockMoment,
  privateReportProBridge,
  archiveBackupBridge,
  paywallPrimaryReason,
  paywallSecondaryReason,
}

/// Raw candidate visibility before priority caps.
class SurfacePriorityCandidates {
  const SurfacePriorityCandidates(this.byKey);

  final Map<SurfacePriorityCardKey, bool> byKey;

  bool candidate(SurfacePriorityCardKey key) => byKey[key] ?? false;

  factory SurfacePriorityCandidates.recordReady({
    required bool firstMomentCapture,
    required bool secondMomentReturn,
    required bool lowFrictionReturn,
    required bool whatToNoticeNext,
    required bool betaTodaySummary,
    required bool openCapturePromptChips,
    required bool captureFreedomLine,
    required bool timelineProofMoment,
    required bool archiveTimelineSpine,
    required bool timelinePositioning,
    required bool currentRelevance,
    required bool correctionMemory,
    required bool notRelevantRecovery,
    required bool evidenceWeighting,
    required bool proofSpecificity,
    required bool presentDayRelevance,
    required bool patternConfidence,
    required bool betaTesterReport,
    required bool proEvidenceValue,
    required bool privateReportProBridge,
    required bool suppressLegacyEducation,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.firstMomentCapture: firstMomentCapture,
        SurfacePriorityCardKey.secondMomentReturn: secondMomentReturn,
        SurfacePriorityCardKey.lowFrictionReturn: lowFrictionReturn,
        SurfacePriorityCardKey.whatToNoticeNext: whatToNoticeNext,
        SurfacePriorityCardKey.betaTodaySummary: betaTodaySummary,
        SurfacePriorityCardKey.openCapturePromptChips: openCapturePromptChips,
        SurfacePriorityCardKey.captureFreedomLine: captureFreedomLine,
        SurfacePriorityCardKey.timelineProofMoment: timelineProofMoment,
        SurfacePriorityCardKey.archiveTimelineSpine: archiveTimelineSpine,
        SurfacePriorityCardKey.timelinePositioning:
            timelinePositioning && !suppressLegacyEducation,
        SurfacePriorityCardKey.currentRelevance:
            currentRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.correctionMemory:
            correctionMemory && !suppressLegacyEducation,
        SurfacePriorityCardKey.notRelevantRecovery: notRelevantRecovery,
        SurfacePriorityCardKey.evidenceWeighting:
            evidenceWeighting && !suppressLegacyEducation,
        SurfacePriorityCardKey.proofSpecificity:
            proofSpecificity && !suppressLegacyEducation,
        SurfacePriorityCardKey.presentDayRelevance:
            presentDayRelevance && !suppressLegacyEducation,
        SurfacePriorityCardKey.patternConfidence:
            patternConfidence && !suppressLegacyEducation,
        SurfacePriorityCardKey.betaTesterReport: betaTesterReport,
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
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
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.proLockMoment: proLockMoment,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
      });

  factory SurfacePriorityCandidates.patterns({
    required bool archiveBeliefSurface,
    required bool timelineProofMoment,
    required bool archiveTimelineSpine,
    required bool betaTesterReport,
    required bool correctionMemory,
    required bool notRelevantRecovery,
    required bool patternConfidence,
    required bool evidenceWeighting,
    required bool currentRelevance,
    required bool proofSpecificity,
    required bool presentDayRelevance,
    required bool timelinePositioning,
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
        SurfacePriorityCardKey.proEvidenceValue: proEvidenceValue,
        SurfacePriorityCardKey.archiveIntelligenceProBridge:
            archiveIntelligenceProBridge,
        SurfacePriorityCardKey.privateReportProBridge: privateReportProBridge,
        SurfacePriorityCardKey.archiveBackupBridge: archiveBackupBridge,
      });

  factory SurfacePriorityCandidates.paywall({
    required bool primaryReason,
    required bool secondaryReason,
  }) =>
      SurfacePriorityCandidates({
        SurfacePriorityCardKey.paywallPrimaryReason: primaryReason,
        SurfacePriorityCardKey.paywallSecondaryReason: secondaryReason,
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
