import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_copy.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_engine.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// Builds one specific next watch target after useful proof.
abstract final class ReturnAfterProofStrengtheningEngine {
  ReturnAfterProofStrengtheningEngine._();

  static const _anchorTypePriority = <EvidenceAnchorType>[
    EvidenceAnchorType.freshReturn,
    EvidenceAnchorType.corrected,
    EvidenceAnchorType.repeat,
    EvidenceAnchorType.change,
    EvidenceAnchorType.softening,
    EvidenceAnchorType.strengthening,
    EvidenceAnchorType.helped,
    EvidenceAnchorType.avoided,
  ];

  static ReturnAfterProofStrengthenedResult build({
    required List<JournalEntry> entries,
    required String source,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    ProofConfidenceCalibrationResult? calibration,
    DateTime? now,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) {
      return ReturnAfterProofStrengthenedResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (entries.length < ReturnAfterProofEngine.minEntryCount) {
      return ReturnAfterProofStrengthenedResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (!firstProofSeen && !timelineProofVisible) {
      return ReturnAfterProofStrengthenedResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final proofConfidence =
        calibration ??
        ProofConfidenceCalibrationEngine.build(
          entries: entries,
          beliefSurfaceVisible: timelineProofVisible || firstProofSeen,
          source: source,
          now: now,
        );
    if (!_hasEligibleConfidence(proofConfidence)) {
      return ReturnAfterProofStrengthenedResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final anchorExtraction = entries.length >= 3
        ? EvidenceAnchorEngine.build(
            entries: entries,
            beliefSurfaceVisible: timelineProofVisible || firstProofSeen,
            source: source,
            now: now,
          )
        : null;
    final targetType = _resolveTargetType(
      anchorExtraction: anchorExtraction,
      calibration: proofConfidence,
    );
    final hasAnchor = anchorExtraction?.hasSafeAnchor ?? false;
    final body = hasAnchor
        ? ReturnAfterProofCopy.bodyForWatchTarget(targetType)
        : ReturnAfterProofCopy.fallbackWatchBody;

    return ReturnAfterProofStrengthenedResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      targetType: targetType,
      confidenceLevel: proofConfidence.level,
      hasAnchor: hasAnchor,
      title: ReturnAfterProofCopy.strengthenedTitle,
      body: body,
      primaryCta: ReturnAfterProofCopy.strengthenedPrimaryCta,
      secondaryCta: ReturnAfterProofCopy.strengthenedSecondaryCta,
      promptLine: ReturnAfterProofCopy.promptLineForWatchTarget(targetType),
    );
  }

  static bool shouldShowOnRecordReady({
    required ReturnAfterProofStrengthenedResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    required bool dismissedForToday,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (result.entryCount < ReturnAfterProofEngine.minEntryCount) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (dismissedForToday) return false;
    if (!firstProofSeen && !timelineProofVisible) return false;
    return true;
  }

  static bool shouldShowOnFirstProofPayoffPostSave({
    required ReturnAfterProofStrengthenedResult? result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (result.entryCount < ReturnAfterProofEngine.minEntryCount) return false;
    if (!showFirstProofPayoff) return false;
    if (isRecording) return false;
    if (isPostSaveDegraded) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (dismissedForToday) return false;
    return true;
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => ReturnAfterProofEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );

  @visibleForTesting
  static ReturnAfterProofWatchTargetType resolveWatchTargetForTest({
    required ProofConfidenceLevel confidenceLevel,
    required bool hasSafeAnchor,
    List<EvidenceAnchorType> anchorTypes = const [],
  }) {
    if (confidenceLevel == ProofConfidenceLevel.freshReturn) {
      return ReturnAfterProofWatchTargetType.notCurrent;
    }
    if (!hasSafeAnchor) {
      return ReturnAfterProofWatchTargetType.returnedAgain;
    }
    final anchors = [
      for (var i = 0; i < anchorTypes.length; i++)
        EvidenceAnchor(
          id: 'test_$i',
          type: anchorTypes[i],
          label: anchorTypes[i].label,
          safeSummary: 'test summary',
          strength: 1,
          recencyWeight: 1,
          sourceCount: 1,
          isUserCorrected: false,
          isFreshReturn: false,
          isSafeForDisplay: true,
        ),
    ];
    return _resolveTargetType(
      anchorExtraction: EvidenceAnchorExtractionResult(
        shouldExtract: true,
        entryCount: 3,
        source: 'test',
        anchors: anchors,
        safeSummaries: const ['test summary'],
        usesFallback: false,
        hasSafeAnchor: true,
        hasRecentAnchor: true,
        hasCorrectionAnchor: anchorTypes.contains(EvidenceAnchorType.corrected),
        hasChangeAnchor: anchorTypes.contains(EvidenceAnchorType.change),
      ),
      calibration: ProofConfidenceCalibrationResult(
        shouldCalibrate: true,
        entryCount: 3,
        source: 'test',
        level: confidenceLevel,
        primaryCopy: '',
        displayCopy: '',
        hasSafeAnchor: true,
        hasMatchQuality: true,
        hasCorrection: false,
        hasFreshReturn: false,
      ),
    );
  }

  static bool _hasEligibleConfidence(
    ProofConfidenceCalibrationResult calibration,
  ) =>
      calibration.level == ProofConfidenceLevel.useful ||
      calibration.level == ProofConfidenceLevel.strong ||
      calibration.level == ProofConfidenceLevel.freshReturn;

  static ReturnAfterProofWatchTargetType _resolveTargetType({
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required ProofConfidenceCalibrationResult calibration,
  }) {
    if (calibration.level == ProofConfidenceLevel.freshReturn) {
      return ReturnAfterProofWatchTargetType.notCurrent;
    }

    if (anchorExtraction?.hasSafeAnchor == true) {
      final anchorsByType = {
        for (final anchor in anchorExtraction!.anchors) anchor.type: anchor,
      };
      for (final type in _anchorTypePriority) {
        if (!anchorsByType.containsKey(type)) continue;
        return _targetForAnchorType(type);
      }
    }

    return ReturnAfterProofWatchTargetType.returnedAgain;
  }

  static ReturnAfterProofWatchTargetType _targetForAnchorType(
    EvidenceAnchorType type,
  ) => switch (type) {
    EvidenceAnchorType.softening => ReturnAfterProofWatchTargetType.feltLighter,
    EvidenceAnchorType.strengthening =>
      ReturnAfterProofWatchTargetType.feltHeavier,
    EvidenceAnchorType.helped => ReturnAfterProofWatchTargetType.helpedAgain,
    EvidenceAnchorType.avoided => ReturnAfterProofWatchTargetType.avoidedAgain,
    EvidenceAnchorType.corrected ||
    EvidenceAnchorType.freshReturn ||
    EvidenceAnchorType.fading => ReturnAfterProofWatchTargetType.notCurrent,
    EvidenceAnchorType.repeat ||
    EvidenceAnchorType.change ||
    EvidenceAnchorType.current ||
    EvidenceAnchorType.unknown => ReturnAfterProofWatchTargetType.returnedAgain,
  };
}