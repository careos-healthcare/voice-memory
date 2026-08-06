import '../../billing/paywall_source.dart';
import '../paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import '../pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import '../pro_bridge_visibility/pro_bridge_visibility_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../proof_quality_response/proof_quality_response_model.dart';
import '../surface_priority/surface_priority_engine.dart';
import '../surface_priority/surface_priority_model.dart';
import 'pro_moment_timing_audit_v2_copy.dart';
import 'pro_moment_timing_audit_v2_model.dart';

/// Internal rule audit for Pro moment timing — no billing or journal access.
abstract final class ProMomentTimingAuditV2Engine {
  ProMomentTimingAuditV2Engine._();

  static const expectedProBridgePaywallSource = PaywallSource.valueMoment;

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static ProMomentTimingAuditV2Snapshot build() {
    final checks = _buildChecks();
    final diagnoses = _buildDiagnoses(checks);
    final readyCount = checks
        .where((check) => check.status == ProMomentTimingAuditV2Status.ready)
        .length;
    final blockedCount = checks
        .where((check) => check.status == ProMomentTimingAuditV2Status.blocked)
        .length;

    return ProMomentTimingAuditV2Snapshot(
      title: ProMomentTimingAuditV2Copy.title,
      subtitle: ProMomentTimingAuditV2Copy.subtitle,
      checks: checks,
      diagnoses: diagnoses,
      readyCount: readyCount,
      blockedCount: blockedCount,
    );
  }

  static List<ProMomentTimingAuditV2Check> _buildChecks() {
    return [
      _check(
        id: ProMomentTimingAuditV2CheckId.neverBeforeFirstProof,
        label: ProMomentTimingAuditV2Copy.checkNeverBeforeFirstProof,
        status: _neverBeforeFirstProofPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _neverBeforeFirstProofPasses()
            ? ProMomentTimingAuditV2Copy.detailBlockedBeforeProof
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.afterUsefulProof,
        label: ProMomentTimingAuditV2Copy.checkAfterUsefulProof,
        status: _afterUsefulProofPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _afterUsefulProofPasses()
            ? ProMomentTimingAuditV2Copy.detailAllowedAfterProof
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.afterStrongProof,
        label: ProMomentTimingAuditV2Copy.checkAfterStrongProof,
        status: _afterStrongProofPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _afterStrongProofPasses()
            ? ProMomentTimingAuditV2Copy.detailAllowedAfterProof
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.afterFreshReturn,
        label: ProMomentTimingAuditV2Copy.checkAfterFreshReturn,
        status: _afterFreshReturnPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _afterFreshReturnPasses()
            ? ProMomentTimingAuditV2Copy.detailAllowedAfterProof
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.afterCorrectionRelevant,
        label: ProMomentTimingAuditV2Copy.checkAfterCorrectionRelevant,
        status: _afterCorrectionPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _afterCorrectionPasses()
            ? ProMomentTimingAuditV2Copy.detailAllowedAfterProof
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.blockedTooVague,
        label: ProMomentTimingAuditV2Copy.checkBlockedTooVague,
        status: _blockedTooVaguePasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _blockedTooVaguePasses()
            ? ProMomentTimingAuditV2Copy.detailBlockedAfterFeedback
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.blockedNotRelevant,
        label: ProMomentTimingAuditV2Copy.checkBlockedNotRelevant,
        status: _blockedNotRelevantPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _blockedNotRelevantPasses()
            ? ProMomentTimingAuditV2Copy.detailBlockedAfterFeedback
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.alreadyKnewNeedsDelta,
        label: ProMomentTimingAuditV2Copy.checkAlreadyKnewNeedsDelta,
        status: _alreadyKnewNeedsDeltaPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _alreadyKnewNeedsDeltaPasses()
            ? ProMomentTimingAuditV2Copy.detailAlreadyKnewWithDelta
            : ProMomentTimingAuditV2Copy.detailAlreadyKnewWithoutDelta,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.notHiddenByGuidance,
        label: ProMomentTimingAuditV2Copy.checkNotHiddenByGuidance,
        status: _notHiddenByGuidancePasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _notHiddenByGuidancePasses()
            ? ProMomentTimingAuditV2Copy.detailVisibleWithGuidance
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.paywallSourceProofConnected,
        label: ProMomentTimingAuditV2Copy.checkPaywallSourceProofConnected,
        status: _paywallSourcePasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _paywallSourcePasses()
            ? ProMomentTimingAuditV2Copy.detailValueMomentSource
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.paywallCopyProofConnected,
        label: ProMomentTimingAuditV2Copy.checkPaywallCopyProofConnected,
        status: _paywallCopyPasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _paywallCopyPasses()
            ? ProMomentTimingAuditV2Copy.detailProofConnectedHeadline
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
      _check(
        id: ProMomentTimingAuditV2CheckId.oneProCardPerSurface,
        label: ProMomentTimingAuditV2Copy.checkOneProCardPerSurface,
        status: _oneProCardPerSurfacePasses()
            ? ProMomentTimingAuditV2Status.ready
            : ProMomentTimingAuditV2Status.blocked,
        detailLabel: _oneProCardPerSurfacePasses()
            ? ProMomentTimingAuditV2Copy.detailSingleProSlot
            : ProMomentTimingAuditV2Copy.detailFailed,
      ),
    ];
  }

  static List<ProMomentTimingAuditV2Diagnosis> _buildDiagnoses(
    List<ProMomentTimingAuditV2Check> checks,
  ) {
    final byId = {for (final check in checks) check.id: check};
    final diagnoses = <ProMomentTimingAuditV2Diagnosis>[];

    if (byId[ProMomentTimingAuditV2CheckId.neverBeforeFirstProof]?.status ==
        ProMomentTimingAuditV2Status.blocked) {
      diagnoses.add(
        const ProMomentTimingAuditV2Diagnosis(
          id: ProMomentTimingAuditV2DiagnosisId.tooEarly,
          title: ProMomentTimingAuditV2Copy.diagnosisTooEarly,
        ),
      );
    }

    final hiddenChecks = [
      ProMomentTimingAuditV2CheckId.afterUsefulProof,
      ProMomentTimingAuditV2CheckId.afterStrongProof,
      ProMomentTimingAuditV2CheckId.afterFreshReturn,
      ProMomentTimingAuditV2CheckId.afterCorrectionRelevant,
      ProMomentTimingAuditV2CheckId.notHiddenByGuidance,
    ];
    if (hiddenChecks.any(
      (id) => byId[id]?.status == ProMomentTimingAuditV2Status.blocked,
    )) {
      diagnoses.add(
        const ProMomentTimingAuditV2Diagnosis(
          id: ProMomentTimingAuditV2DiagnosisId.tooHidden,
          title: ProMomentTimingAuditV2Copy.diagnosisTooHidden,
        ),
      );
    }

    final sourceChecks = [
      ProMomentTimingAuditV2CheckId.paywallSourceProofConnected,
      ProMomentTimingAuditV2CheckId.paywallCopyProofConnected,
    ];
    if (sourceChecks.any(
      (id) => byId[id]?.status == ProMomentTimingAuditV2Status.blocked,
    )) {
      diagnoses.add(
        const ProMomentTimingAuditV2Diagnosis(
          id: ProMomentTimingAuditV2DiagnosisId.wrongSource,
          title: ProMomentTimingAuditV2Copy.diagnosisWrongSource,
        ),
      );
    }

    if (byId[ProMomentTimingAuditV2CheckId.oneProCardPerSurface]?.status ==
        ProMomentTimingAuditV2Status.blocked) {
      diagnoses.add(
        const ProMomentTimingAuditV2Diagnosis(
          id: ProMomentTimingAuditV2DiagnosisId.tooCluttered,
          title: ProMomentTimingAuditV2Copy.diagnosisTooCluttered,
        ),
      );
    }

    if (diagnoses.isEmpty &&
        checks.every(
          (check) => check.status == ProMomentTimingAuditV2Status.ready,
        )) {
      diagnoses.add(
        const ProMomentTimingAuditV2Diagnosis(
          id: ProMomentTimingAuditV2DiagnosisId.correct,
          title: ProMomentTimingAuditV2Copy.diagnosisCorrect,
        ),
      );
    }

    return diagnoses;
  }

  static bool _neverBeforeFirstProofPasses() {
    final beforeProof = ProBridgeVisibilityEngine.shouldShow(
      input: _input(
        hasFirstProof: false,
        hasTimelineProofVisible: false,
        entryCount: 2,
      ),
    );
    final zeroEntry = ProBridgeVisibilityEngine.shouldShow(
      input: _input(
        entryCount: 0,
        isZeroEntryState: true,
        hasFirstProof: false,
        hasTimelineProofVisible: false,
      ),
    );
    return !beforeProof && !zeroEntry;
  }

  static bool _afterUsefulProofPasses() => ProBridgeVisibilityEngine.shouldShow(
    input: _input(
      hasTimelineProofVisible: false,
      feedbackState: ProofQualityFeedbackState.useful,
    ),
  );

  static bool _afterStrongProofPasses() => ProBridgeVisibilityEngine.shouldShow(
    input: _input(
      hasTimelineProofVisible: false,
      confidenceLevel: ProofConfidenceLevel.strong,
      hasSafeAnchor: true,
    ),
  );

  static bool _afterFreshReturnPasses() => ProBridgeVisibilityEngine.shouldShow(
    input: _input(
      hasTimelineProofVisible: false,
      hasFreshReturnAfterCorrection: true,
      confidenceLevel: ProofConfidenceLevel.freshReturn,
      hasSafeAnchor: true,
    ),
  );

  static bool _afterCorrectionPasses() => ProBridgeVisibilityEngine.shouldShow(
    input: _input(
      hasTimelineProofVisible: false,
      hasCorrectionMemoryVisible: true,
    ),
  );

  static bool _blockedTooVaguePasses() => !ProBridgeVisibilityEngine.shouldShow(
    input: _input(
      feedbackState: ProofQualityFeedbackState.tooVague,
      hasTimelineProofVisible: true,
    ),
  );

  static bool _blockedNotRelevantPasses() =>
      !ProBridgeVisibilityEngine.shouldShow(
        input: _input(
          feedbackState: ProofQualityFeedbackState.notRelevant,
          hasTimelineProofVisible: true,
        ),
      );

  static bool _alreadyKnewNeedsDeltaPasses() {
    final withoutDelta = ProBridgeVisibilityEngine.shouldShow(
      input: _input(
        hasTimelineProofVisible: false,
        hasFirstProofPayoffVisible: false,
        hasCorrectionMemoryVisible: false,
        hasFreshReturnAfterCorrection: false,
        feedbackState: ProofQualityFeedbackState.alreadyKnewThis,
      ),
    );
    final withDelta = ProBridgeVisibilityEngine.shouldShow(
      input: _input(
        hasTimelineProofVisible: false,
        hasCorrectionMemoryVisible: true,
        feedbackState: ProofQualityFeedbackState.alreadyKnewThis,
      ),
    );
    return !withoutDelta && withDelta;
  }

  static bool _notHiddenByGuidancePasses() {
    final audit = SurfacePriorityEngine.auditRecordReady(
      entryCount: 3,
      source: 'pro_moment_timing_audit_v2',
      candidates: _recordReadyWithGuidanceAndPro(),
    );
    return audit.isVisible(
      SurfacePriorityCardKey.proBridgeVisibility,
      candidate: true,
    );
  }

  static bool _paywallSourcePasses() =>
      expectedProBridgePaywallSource == PaywallSource.valueMoment &&
      PaywallValueSharpeningCopy.isProofConnectedSource(
        expectedProBridgePaywallSource,
      );

  static bool _paywallCopyPasses() =>
      PaywallValueSharpeningCopy.headlineFor(expectedProBridgePaywallSource) ==
      PaywallValueSharpeningCopy.proofConnectedHeadline;

  static bool _oneProCardPerSurfacePasses() {
    final postSave = SurfacePriorityEngine.auditRecordPostSave(
      entryCount: 3,
      source: 'pro_moment_timing_audit_v2',
      candidates: SurfacePriorityCandidates.recordPostSave(
        lowFrictionReturn: false,
        whatToNoticeNext: false,
        betaTodaySummary: false,
        openCapturePromptChips: false,
        captureFreedomLine: false,
        whatChanged: false,
        firstProofPayoff: true,
        returnPayoff: false,
        timelineProofMomentPostSave: true,
        proofSpecificityPostSave: false,
        betaProofFeedback: false,
        proBridgeVisibility: true,
        proEvidenceValue: true,
        proLockMoment: true,
        privateReportProBridge: true,
      ),
    );
    final proVisible = postSave.visibleCardKeys
        .where(
          (key) =>
              key == SurfacePriorityCardKey.proBridgeVisibility ||
              key == SurfacePriorityCardKey.proEvidenceValue ||
              key == SurfacePriorityCardKey.proLockMoment ||
              key == SurfacePriorityCardKey.privateReportProBridge,
        )
        .length;
    return proVisible == 1 && postSave.proSlot != null;
  }

  static ProBridgeVisibilityInput _input({
    ProBridgeVisibilitySurface surface = ProBridgeVisibilitySurface.recordReady,
    int entryCount = 3,
    bool isPro = false,
    bool postProofProBridgeEnabled = true,
    bool hasFirstProof = true,
    bool hasTimelineProofVisible = true,
    bool hasFirstProofPayoffVisible = false,
    bool hasBetaTesterReportVisible = false,
    bool hasCorrectionMemoryVisible = false,
    bool hasBetaProofLiftVisible = false,
    bool hasReturnAfterProofStrengthenedVisible = false,
    ProofQualityFeedbackState feedbackState = ProofQualityFeedbackState.none,
    ProofConfidenceLevel? confidenceLevel,
    bool hasSafeAnchor = false,
    bool hasFreshReturnAfterCorrection = false,
    bool hasSolidStrongPatternWithSafeAnchors = false,
    bool isRecording = false,
    bool isZeroEntryState = false,
    bool isFirstRecordingState = false,
    bool isPostSaveDegradedState = false,
    bool isDegradedTranscriptState = false,
    bool whatChangedQuestionActive = false,
    bool patternReviewInboxHasActiveItems = false,
    bool proSlotAvailable = true,
    bool hasSeenFirstRepeat = true,
    bool hasOpenedEvidenceTrail = true,
  }) => ProBridgeVisibilityInput(
    surface: surface,
    source: 'pro_moment_timing_audit_v2',
    entryCount: entryCount,
    isPro: isPro,
    postProofProBridgeEnabled: postProofProBridgeEnabled,
    hasFirstProof: hasFirstProof,
    hasTimelineProofVisible: hasTimelineProofVisible,
    hasFirstProofPayoffVisible: hasFirstProofPayoffVisible,
    hasBetaTesterReportVisible: hasBetaTesterReportVisible,
    hasCorrectionMemoryVisible: hasCorrectionMemoryVisible,
    hasBetaProofLiftVisible: hasBetaProofLiftVisible,
    hasReturnAfterProofStrengthenedVisible:
        hasReturnAfterProofStrengthenedVisible,
    feedbackState: feedbackState,
    confidenceLevel: confidenceLevel,
    hasSafeAnchor: hasSafeAnchor,
    hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
    hasSolidStrongPatternWithSafeAnchors: hasSolidStrongPatternWithSafeAnchors,
    isRecording: isRecording,
    isZeroEntryState: isZeroEntryState,
    isFirstRecordingState: isFirstRecordingState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    isDegradedTranscriptState: isDegradedTranscriptState,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    proSlotAvailable: proSlotAvailable,
    hasSeenFirstRepeat: hasSeenFirstRepeat,
    hasOpenedEvidenceTrail: hasOpenedEvidenceTrail,
  );

  static SurfacePriorityCandidates _recordReadyWithGuidanceAndPro() =>
      SurfacePriorityCandidates.recordReady(
        threeMomentCompletion: true,
        firstMomentCapture: false,
        secondMomentReturn: false,
        returnAfterProofStrengthened: false,
        returnAfterProof: false,
        lowFrictionReturn: false,
        whatToNoticeNext: false,
        betaTodaySummary: false,
        openCapturePromptChips: false,
        captureFreedomLine: false,
        firstRunPositioning: false,
        timelineProofMoment: false,
        archiveTimelineSpine: false,
        timelinePositioning: false,
        currentRelevance: false,
        correctionMemory: false,
        notRelevantRecovery: false,
        proofQualityResponse: false,
        evidenceWeighting: false,
        proofSpecificity: false,
        presentDayRelevance: false,
        patternConfidence: false,
        betaTesterReport: false,
        proBridgeVisibility: true,
        proEvidenceValue: false,
        privateReportProBridge: false,
        suppressLegacyEducation: false,
      );

  static ProMomentTimingAuditV2Check _check({
    required ProMomentTimingAuditV2CheckId id,
    required String label,
    required ProMomentTimingAuditV2Status status,
    required String detailLabel,
  }) => ProMomentTimingAuditV2Check(
    id: id,
    label: label,
    status: status,
    detailLabel: detailLabel,
  );
}
