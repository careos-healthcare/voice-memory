import '../../config/developer_settings_gate.dart';
import '../first_run_positioning/first_run_positioning_engine.dart';
import '../../core/config/v1_feature_flags.dart';
import 'surface_priority_copy.dart';
import 'surface_priority_model.dart';

/// Caps competing guidance, proof, correction, report, and Pro cards per surface.
abstract final class SurfacePriorityEngine {
  SurfacePriorityEngine._();

  static const _guidanceOrder = [
    SurfacePriorityCardKey.firstSessionProofRepair,
    SurfacePriorityCardKey.firstSessionLift,
    SurfacePriorityCardKey.firstSaveLift,
    SurfacePriorityCardKey.betaActivationPath,
    SurfacePriorityCardKey.threeMomentCompletion,
    SurfacePriorityCardKey.firstMomentCapture,
    SurfacePriorityCardKey.secondMomentReturn,
    SurfacePriorityCardKey.returnAfterProofStrengthened,
    SurfacePriorityCardKey.returnAfterProofLiftV2,
    SurfacePriorityCardKey.returnAfterProof,
    SurfacePriorityCardKey.lowFrictionReturn,
    SurfacePriorityCardKey.whatToNoticeNext,
    SurfacePriorityCardKey.betaTodaySummary,
    SurfacePriorityCardKey.openCapturePromptChips,
    SurfacePriorityCardKey.captureFreedomLine,
  ];

  static const _recordProofOrder = [
    SurfacePriorityCardKey.timelineProofMoment,
    SurfacePriorityCardKey.archiveTimelineSpine,
    SurfacePriorityCardKey.timelinePositioning,
    SurfacePriorityCardKey.evidenceWeighting,
    SurfacePriorityCardKey.proofSpecificity,
    SurfacePriorityCardKey.presentDayRelevance,
    SurfacePriorityCardKey.patternConfidence,
  ];

  static const _recordCorrectionOrder = [
    SurfacePriorityCardKey.proofFloorRescue,
    SurfacePriorityCardKey.proofQualityRepair,
    SurfacePriorityCardKey.proofQualityResponse,
    SurfacePriorityCardKey.betaProofLift,
    SurfacePriorityCardKey.notRelevantRecovery,
    SurfacePriorityCardKey.currentRelevance,
    SurfacePriorityCardKey.correctionMemory,
  ];

  static const _patternsDetailOrder = [
    SurfacePriorityCardKey.proofQualityResponse,
    SurfacePriorityCardKey.betaProofLift,
    SurfacePriorityCardKey.notRelevantRecovery,
    SurfacePriorityCardKey.correctionMemory,
    SurfacePriorityCardKey.patternConfidence,
    SurfacePriorityCardKey.evidenceWeighting,
  ];

  static const _patternsTimelineOrder = [
    SurfacePriorityCardKey.archiveBeliefSurface,
    SurfacePriorityCardKey.timelineProofMoment,
    SurfacePriorityCardKey.archiveTimelineSpine,
  ];

  static const _recordProOrder = [
    SurfacePriorityCardKey.proUnderstandingLift,
    SurfacePriorityCardKey.proVisibilityLift,
    SurfacePriorityCardKey.proPreview,
    SurfacePriorityCardKey.proBridgeVisibility,
    SurfacePriorityCardKey.proEvidenceValue,
    SurfacePriorityCardKey.privateReportProBridge,
    SurfacePriorityCardKey.betaActivationPathRevenue,
  ];

  static const _patternsProOrder = [
    SurfacePriorityCardKey.proUnderstandingLift,
    SurfacePriorityCardKey.proVisibilityLift,
    SurfacePriorityCardKey.proPreview,
    SurfacePriorityCardKey.proBridgeVisibility,
    SurfacePriorityCardKey.proEvidenceValue,
    SurfacePriorityCardKey.archiveIntelligenceProBridge,
    SurfacePriorityCardKey.privateReportProBridge,
    SurfacePriorityCardKey.archiveBackupBridge,
  ];

  static const _postSaveProOrder = [
    SurfacePriorityCardKey.proUnderstandingLift,
    SurfacePriorityCardKey.proVisibilityLift,
    SurfacePriorityCardKey.proPreview,
    SurfacePriorityCardKey.proBridgeVisibility,
    SurfacePriorityCardKey.proEvidenceValue,
    SurfacePriorityCardKey.proLockMoment,
    SurfacePriorityCardKey.privateReportProBridge,
  ];

  static SurfacePriorityResult auditRecordReady({
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
  }) {
    final visible = <SurfacePriorityCardKey>[];
    final hiddenReasons = <String>[];

    final guidanceSlot = _pickFirst(candidates, _guidanceOrder);
    if (guidanceSlot != null) {
      visible.add(guidanceSlot);
    }
    _suppress(
      candidates,
      _guidanceOrder,
      winner: guidanceSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: SurfacePriorityCopy.hiddenReasonGuidanceCap,
    );

    if (entryCount <= 1 &&
        candidates.candidate(SurfacePriorityCardKey.firstRunPositioning) &&
        FirstRunPositioningEngine.allowsEducationSlot(
          guidanceSlot: guidanceSlot,
        )) {
      visible.add(SurfacePriorityCardKey.firstRunPositioning);
    } else if (entryCount <= 1 &&
        candidates.candidate(SurfacePriorityCardKey.firstRunPositioning)) {
      hiddenReasons.add(SurfacePriorityCopy.hiddenReasonFirstRunEducationCap);
    }

    final proofSlot = _pickFirst(candidates, _recordProofOrder);
    if (proofSlot != null) {
      visible.add(proofSlot);
    }
    _suppress(
      candidates,
      _recordProofOrder,
      winner: proofSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: SurfacePriorityCopy.hiddenReasonProofCap,
    );

    final correctionSlot = _pickFirst(candidates, _recordCorrectionOrder);
    if (correctionSlot != null &&
        proofSlot != SurfacePriorityCardKey.currentRelevance &&
        proofSlot != SurfacePriorityCardKey.correctionMemory) {
      visible.add(correctionSlot);
    } else if (correctionSlot != null &&
        proofSlot != correctionSlot &&
        (proofSlot == SurfacePriorityCardKey.timelineProofMoment ||
            proofSlot == SurfacePriorityCardKey.archiveTimelineSpine)) {
      visible.add(correctionSlot);
    }
    _suppress(
      candidates,
      _recordCorrectionOrder,
      winner: correctionSlot != null && visible.contains(correctionSlot)
          ? correctionSlot
          : null,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: SurfacePriorityCopy.hiddenReasonCorrectionCap,
    );

    final reportCandidate = candidates.candidate(
      SurfacePriorityCardKey.betaTesterReport,
    );
    SurfacePriorityCardKey? reportSlot;
    if (reportCandidate) {
      final proofCount = visible
          .where(
            (key) =>
                key == SurfacePriorityCardKey.timelineProofMoment ||
                key == SurfacePriorityCardKey.archiveTimelineSpine,
          )
          .length;
      final hasGuidance = guidanceSlot != null;
      if (proofCount <= 1 && !hasGuidance && proofSlot != null) {
        reportSlot = SurfacePriorityCardKey.betaTesterReport;
        visible.add(reportSlot);
      } else if (proofCount > 1 || hasGuidance) {
        hiddenReasons.add(
          SurfacePriorityCopy.hiddenReasonReportWithMultipleProof,
        );
      }
    }

    final proSlot = _pickProSlot(candidates, _recordProOrder);
    if (proSlot != null) {
      visible.add(proSlot);
    }
    _suppress(
      candidates,
      _recordProOrder,
      winner: proSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: candidates.candidate(SurfacePriorityCardKey.proofFloorRescue)
          ? SurfacePriorityCopy.hiddenReasonProofFloorBlocksPro
          : SurfacePriorityCopy.hiddenReasonProCap,
    );

    _addBetaFeedbackCaptureIfAllowed(candidates, visible, hiddenReasons);

    return _result(
      surface: SurfacePrioritySurface.recordReady,
      entryCount: entryCount,
      source: source,
      candidates: candidates,
      visible: visible,
      hiddenReasons: hiddenReasons,
      guidanceSlot: guidanceSlot,
      proofSlot: proofSlot,
      correctionSlot: correctionSlot != null && visible.contains(correctionSlot)
          ? correctionSlot
          : null,
      reportSlot: reportSlot,
      proSlot: proSlot,
    );
  }

  static SurfacePriorityResult auditRecordPostSave({
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
  }) {
    if (V1FeatureFlags.enableV1Only) {
      return _auditRecordPostSaveV1(
        entryCount: entryCount,
        source: source,
        candidates: candidates,
      );
    }
    final visible = <SurfacePriorityCardKey>[];
    final hiddenReasons = <String>[];

    for (final key in _guidanceOrder) {
      if (candidates.candidate(key)) {
        hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPostSaveGuidance);
      }
    }

    final whatChangedActive = candidates.candidate(
      SurfacePriorityCardKey.whatChanged,
    );
    final firstProofActive = candidates.candidate(
      SurfacePriorityCardKey.firstProofPayoff,
    );
    final returnPayoffActive = candidates.candidate(
      SurfacePriorityCardKey.returnPayoff,
    );

    if (whatChangedActive) {
      visible.add(SurfacePriorityCardKey.whatChanged);
      hiddenReasons.add(
        SurfacePriorityCopy.hiddenReasonPostSaveWhatChangedWins,
      );
    } else if (firstProofActive) {
      visible.add(SurfacePriorityCardKey.firstProofPayoff);
      hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPostSaveFirstProofWins);
      if (candidates.candidate(
        SurfacePriorityCardKey.timelineProofMomentPostSave,
      )) {
        visible.add(SurfacePriorityCardKey.timelineProofMomentPostSave);
      }
      if (candidates.candidate(
        SurfacePriorityCardKey.proofSpecificityPostSave,
      )) {
        visible.add(SurfacePriorityCardKey.proofSpecificityPostSave);
      }
      if (candidates.candidate(SurfacePriorityCardKey.betaProofFeedback)) {
        visible.add(SurfacePriorityCardKey.betaProofFeedback);
      }
      if (candidates.candidate(SurfacePriorityCardKey.betaProofLift)) {
        visible.add(SurfacePriorityCardKey.betaProofLift);
      }
      if (candidates.candidate(SurfacePriorityCardKey.betaInviteLoop)) {
        visible.add(SurfacePriorityCardKey.betaInviteLoop);
      }
      if (candidates.candidate(SurfacePriorityCardKey.returnAfterProofLiftV2)) {
        visible.add(SurfacePriorityCardKey.returnAfterProofLiftV2);
      } else if (candidates.candidate(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
      )) {
        visible.add(SurfacePriorityCardKey.returnAfterProofStrengthened);
      } else if (candidates.candidate(
        SurfacePriorityCardKey.returnAfterProof,
      )) {
        visible.add(SurfacePriorityCardKey.returnAfterProof);
      }
    } else if (returnPayoffActive) {
      visible.add(SurfacePriorityCardKey.returnPayoff);
      hiddenReasons.add(
        SurfacePriorityCopy.hiddenReasonPostSaveReturnPayoffWins,
      );
    }

    final proSlot = _pickProSlot(candidates, _postSaveProOrder);
    if (proSlot != null) {
      visible.add(proSlot);
    }
    _suppress(
      candidates,
      _postSaveProOrder,
      winner: proSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: candidates.candidate(SurfacePriorityCardKey.proofFloorRescue)
          ? SurfacePriorityCopy.hiddenReasonProofFloorBlocksPro
          : SurfacePriorityCopy.hiddenReasonProCap,
    );

    _addBetaFeedbackCaptureIfAllowed(candidates, visible, hiddenReasons);

    return _result(
      surface: SurfacePrioritySurface.recordPostSave,
      entryCount: entryCount,
      source: source,
      candidates: candidates,
      visible: visible,
      hiddenReasons: hiddenReasons,
      proofSlot: whatChangedActive
          ? SurfacePriorityCardKey.whatChanged
          : firstProofActive
          ? SurfacePriorityCardKey.firstProofPayoff
          : returnPayoffActive
          ? SurfacePriorityCardKey.returnPayoff
          : null,
      proSlot: proSlot,
    );
  }

  /// V1 launch: one cautious verified result max; no beta/pro/retention cards.
  static SurfacePriorityResult _auditRecordPostSaveV1({
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
  }) {
    final visible = <SurfacePriorityCardKey>[];
    final hiddenReasons = <String>['v1_post_save_lab_quarantined'];

    for (final key in _guidanceOrder) {
      if (candidates.candidate(key)) {
        hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPostSaveGuidance);
      }
    }

    SurfacePriorityCardKey? proofSlot;
    if (candidates.candidate(SurfacePriorityCardKey.whatChanged)) {
      visible.add(SurfacePriorityCardKey.whatChanged);
      proofSlot = SurfacePriorityCardKey.whatChanged;
      hiddenReasons.add(
        SurfacePriorityCopy.hiddenReasonPostSaveWhatChangedWins,
      );
    } else if (candidates.candidate(SurfacePriorityCardKey.firstProofPayoff)) {
      visible.add(SurfacePriorityCardKey.firstProofPayoff);
      proofSlot = SurfacePriorityCardKey.firstProofPayoff;
      hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPostSaveFirstProofWins);
    }

    for (final key in [
      SurfacePriorityCardKey.timelineProofMomentPostSave,
      SurfacePriorityCardKey.proofSpecificityPostSave,
      SurfacePriorityCardKey.betaProofFeedback,
      SurfacePriorityCardKey.betaProofLift,
      SurfacePriorityCardKey.betaInviteLoop,
      SurfacePriorityCardKey.returnAfterProofLiftV2,
      SurfacePriorityCardKey.returnAfterProofStrengthened,
      SurfacePriorityCardKey.returnAfterProof,
      SurfacePriorityCardKey.returnPayoff,
      ..._postSaveProOrder,
      SurfacePriorityCardKey.betaFeedbackCapture,
    ]) {
      if (candidates.candidate(key)) {
        hiddenReasons.add(SurfacePriorityCopy.hiddenReasonProCap);
      }
    }

    return _result(
      surface: SurfacePrioritySurface.recordPostSave,
      entryCount: entryCount,
      source: source,
      candidates: candidates,
      visible: visible,
      hiddenReasons: hiddenReasons,
      proofSlot: proofSlot,
    );
  }

  static SurfacePriorityResult auditPatterns({
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
  }) {
    final visible = <SurfacePriorityCardKey>[];
    final hiddenReasons = <String>[];

    for (final key in _patternsTimelineOrder) {
      if (candidates.candidate(key)) {
        visible.add(key);
      }
    }

    final timelineProofVisible = visible.contains(
      SurfacePriorityCardKey.timelineProofMoment,
    );

    final detailCandidates = timelineProofVisible
        ? _patternsDetailOrder
              .where(
                (key) =>
                    key != SurfacePriorityCardKey.patternConfidence &&
                    key != SurfacePriorityCardKey.evidenceWeighting,
              )
              .toList()
        : _patternsDetailOrder;

    final detailSlot = _pickFirst(candidates, detailCandidates);
    if (detailSlot != null) {
      visible.add(detailSlot);
    }
    _suppress(
      candidates,
      _patternsDetailOrder,
      winner: detailSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: timelineProofVisible
          ? SurfacePriorityCopy.hiddenReasonPatternsDuplicateTimeline
          : SurfacePriorityCopy.hiddenReasonPatternsDetailCap,
    );

    _suppress(
      candidates,
      [
        SurfacePriorityCardKey.currentRelevance,
        SurfacePriorityCardKey.proofSpecificity,
        SurfacePriorityCardKey.presentDayRelevance,
        SurfacePriorityCardKey.timelinePositioning,
      ],
      winner: null,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: SurfacePriorityCopy.hiddenReasonPatternsDetailCap,
    );

    if (candidates.candidate(SurfacePriorityCardKey.betaTesterReport)) {
      visible.add(SurfacePriorityCardKey.betaTesterReport);
    }
    if (candidates.candidate(SurfacePriorityCardKey.betaInviteLoop)) {
      visible.add(SurfacePriorityCardKey.betaInviteLoop);
    }

    final timelineVisible = visible.any(
      (key) =>
          key == SurfacePriorityCardKey.archiveBeliefSurface ||
          key == SurfacePriorityCardKey.timelineProofMoment ||
          key == SurfacePriorityCardKey.archiveTimelineSpine ||
          key == SurfacePriorityCardKey.betaTesterReport,
    );

    final proSlot = timelineVisible
        ? _pickProSlot(candidates, _patternsProOrder)
        : null;
    if (proSlot != null) {
      visible.add(proSlot);
    }
    if (!timelineVisible) {
      for (final key in _patternsProOrder) {
        if (candidates.candidate(key)) {
          hiddenReasons.add(
            SurfacePriorityCopy.hiddenReasonPatternsProBeforeTimeline,
          );
        }
      }
    }
    _suppress(
      candidates,
      _patternsProOrder,
      winner: proSlot,
      visible: visible,
      hiddenReasons: hiddenReasons,
      reason: candidates.candidate(SurfacePriorityCardKey.proofFloorRescue)
          ? SurfacePriorityCopy.hiddenReasonProofFloorBlocksPro
          : SurfacePriorityCopy.hiddenReasonProCap,
    );

    _addBetaFeedbackCaptureIfAllowed(candidates, visible, hiddenReasons);

    return _result(
      surface: SurfacePrioritySurface.patterns,
      entryCount: entryCount,
      source: source,
      candidates: candidates,
      visible: visible,
      hiddenReasons: hiddenReasons,
      proofSlot: visible.contains(SurfacePriorityCardKey.timelineProofMoment)
          ? SurfacePriorityCardKey.timelineProofMoment
          : visible.contains(SurfacePriorityCardKey.archiveTimelineSpine)
          ? SurfacePriorityCardKey.archiveTimelineSpine
          : null,
      correctionSlot: detailSlot,
      reportSlot: visible.contains(SurfacePriorityCardKey.betaTesterReport)
          ? SurfacePriorityCardKey.betaTesterReport
          : null,
      proSlot: proSlot,
    );
  }

  static SurfacePriorityResult auditPaywall({
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
  }) {
    final visible = <SurfacePriorityCardKey>[];
    final hiddenReasons = <String>[];

    if (candidates.candidate(SurfacePriorityCardKey.paywallPrimaryReason)) {
      visible.add(SurfacePriorityCardKey.paywallPrimaryReason);
    }
    if (candidates.candidate(SurfacePriorityCardKey.paywallCtaLift)) {
      visible.add(SurfacePriorityCardKey.paywallCtaLift);
    }
    if (candidates.candidate(SurfacePriorityCardKey.paywallSecondaryReason)) {
      hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPaywallDuplicateReason);
    }
    _addBetaFeedbackCaptureIfAllowed(candidates, visible, hiddenReasons);

    return _result(
      surface: SurfacePrioritySurface.paywall,
      entryCount: entryCount,
      source: source,
      candidates: candidates,
      visible: visible,
      hiddenReasons: hiddenReasons,
      proSlot: visible.contains(SurfacePriorityCardKey.paywallPrimaryReason)
          ? SurfacePriorityCardKey.paywallPrimaryReason
          : null,
    );
  }

  static bool allowsBetaTesterReportOnRecord({
    required SurfacePriorityResult audit,
  }) =>
      audit.isVisible(SurfacePriorityCardKey.betaTesterReport, candidate: true);

  static bool allowsWhatToNoticeNextOnRecord({
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool openCapturePromptChipsVisible,
  }) {
    final guidanceCount =
        (lowFrictionReturnVisible ? 1 : 0) +
        (betaTodaySummaryVisible ? 1 : 0) +
        (openCapturePromptChipsVisible ? 1 : 0);
    return guidanceCount <= 1;
  }

  static bool allowsBetaTesterReportOnRecordLegacy({
    required bool lowFrictionReturnVisible,
    required bool betaTodaySummaryVisible,
    required bool whatToNoticeNextVisible,
    required bool openCapturePromptChipsVisible,
    required bool timelineProofMomentVisible,
    required bool archiveTimelineSpineVisible,
  }) {
    final audit = auditRecordReady(
      entryCount: 0,
      source: 'legacy',
      candidates: SurfacePriorityCandidates.recordReady(
        threeMomentCompletion: false,
        firstMomentCapture: false,
        secondMomentReturn: false,
        lowFrictionReturn: lowFrictionReturnVisible,
        whatToNoticeNext: whatToNoticeNextVisible,
        betaTodaySummary: betaTodaySummaryVisible,
        openCapturePromptChips: openCapturePromptChipsVisible,
        captureFreedomLine: false,
        timelineProofMoment: timelineProofMomentVisible,
        archiveTimelineSpine: archiveTimelineSpineVisible,
        timelinePositioning: false,
        currentRelevance: false,
        correctionMemory: false,
        notRelevantRecovery: false,
        proofQualityResponse: false,
        evidenceWeighting: false,
        proofSpecificity: false,
        presentDayRelevance: false,
        patternConfidence: false,
        betaTesterReport: true,
        proEvidenceValue: false,
        privateReportProBridge: false,
        suppressLegacyEducation: false,
      ),
    );
    return audit.isVisible(
      SurfacePriorityCardKey.betaTesterReport,
      candidate: true,
    );
  }

  static void _addBetaFeedbackCaptureIfAllowed(
    SurfacePriorityCandidates candidates,
    List<SurfacePriorityCardKey> visible,
    List<String> hiddenReasons,
  ) {
    if (!candidates.candidate(SurfacePriorityCardKey.betaFeedbackCapture)) {
      return;
    }
    if (candidates.candidate(SurfacePriorityCardKey.firstMomentCapture) ||
        candidates.candidate(SurfacePriorityCardKey.threeMomentCompletion) ||
        candidates.candidate(SurfacePriorityCardKey.secondMomentReturn)) {
      hiddenReasons.add(SurfacePriorityCopy.hiddenReasonPostSaveGuidance);
      return;
    }
    if (candidates.candidate(SurfacePriorityCardKey.whatChanged)) {
      hiddenReasons.add(
        SurfacePriorityCopy.hiddenReasonPostSaveWhatChangedWins,
      );
      return;
    }
    visible.add(SurfacePriorityCardKey.betaFeedbackCapture);
  }

  static SurfacePriorityCardKey? _pickProSlot(
    SurfacePriorityCandidates candidates,
    List<SurfacePriorityCardKey> order,
  ) {
    if (candidates.candidate(SurfacePriorityCardKey.proofFloorRescue)) {
      return null;
    }
    return _pickFirst(candidates, order);
  }

  static SurfacePriorityCardKey? _pickFirst(
    SurfacePriorityCandidates candidates,
    List<SurfacePriorityCardKey> order,
  ) {
    for (final key in order) {
      if (candidates.candidate(key)) return key;
    }
    return null;
  }

  static void _suppress(
    SurfacePriorityCandidates candidates,
    List<SurfacePriorityCardKey> order, {
    required SurfacePriorityCardKey? winner,
    required List<SurfacePriorityCardKey> visible,
    required List<String> hiddenReasons,
    required String reason,
  }) {
    for (final key in order) {
      if (key == winner || !candidates.candidate(key)) continue;
      if (!hiddenReasons.contains(reason)) {
        hiddenReasons.add(reason);
      }
    }
  }

  static SurfacePriorityResult _result({
    required SurfacePrioritySurface surface,
    required int entryCount,
    required String source,
    required SurfacePriorityCandidates candidates,
    required List<SurfacePriorityCardKey> visible,
    required List<String> hiddenReasons,
    SurfacePriorityCardKey? captureSlot,
    SurfacePriorityCardKey? guidanceSlot,
    SurfacePriorityCardKey? proofSlot,
    SurfacePriorityCardKey? correctionSlot,
    SurfacePriorityCardKey? reportSlot,
    SurfacePriorityCardKey? proSlot,
  }) {
    final candidateCount = candidates.byKey.values.where((v) => v).length;
    final suppressedCardCount = candidateCount - visible.length;

    return SurfacePriorityResult(
      surface: surface,
      entryCount: entryCount,
      source: source,
      captureSlot: captureSlot,
      guidanceSlot: guidanceSlot,
      proofSlot: proofSlot,
      correctionSlot: correctionSlot,
      reportSlot: reportSlot,
      proSlot: proSlot,
      hiddenReasons: hiddenReasons,
      visibleCardKeys: visible,
      shouldShowDebugSummary: DeveloperSettingsGate.canShowDeveloperSettings,
      suppressedCardCount: suppressedCardCount < 0 ? 0 : suppressedCardCount,
    );
  }
}
