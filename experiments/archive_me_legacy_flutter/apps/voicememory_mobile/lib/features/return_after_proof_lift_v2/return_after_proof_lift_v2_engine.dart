import '../../models/journal_entry.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../return_after_proof/return_after_proof_copy.dart';
import '../return_after_proof/return_after_proof_engine.dart';
import '../return_after_proof/return_after_proof_strengthening_engine.dart';
import 'return_after_proof_lift_v2_copy.dart';
import 'return_after_proof_lift_v2_model.dart';
import 'return_after_proof_lift_v2_store.dart';

/// Stronger return hook after useful proof — beats generic return cards.
abstract final class ReturnAfterProofLiftV2Engine {
  ReturnAfterProofLiftV2Engine._();

  static ReturnAfterProofLiftV2Result build({
    required List<JournalEntry> entries,
    required String source,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    ProofConfidenceCalibrationResult? calibration,
    DateTime? now,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) {
      return ReturnAfterProofLiftV2Result.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (ReturnAfterProofLiftV2Store.isDismissedToday) {
      return ReturnAfterProofLiftV2Result.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (entries.length < ReturnAfterProofEngine.minEntryCount) {
      return ReturnAfterProofLiftV2Result.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (!firstProofSeen && !timelineProofVisible) {
      return ReturnAfterProofLiftV2Result.hidden(
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
      return ReturnAfterProofLiftV2Result.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final strengthened = ReturnAfterProofStrengtheningEngine.build(
      entries: entries,
      source: source,
      firstProofSeen: firstProofSeen,
      timelineProofVisible: timelineProofVisible,
      calibration: proofConfidence,
      now: now,
    );
    final targetType = strengthened.targetType;
    final hasAnchor = strengthened.hasAnchor;
    final watchLine = hasAnchor
        ? ReturnAfterProofLiftV2Copy.watchLineFor(targetType)
        : ReturnAfterProofLiftV2Copy.fallbackWatchLine;

    return ReturnAfterProofLiftV2Result(
      shouldShow: true,
      title: ReturnAfterProofLiftV2Copy.title,
      body: ReturnAfterProofLiftV2Copy.body,
      watchLine: watchLine,
      primaryCta: ReturnAfterProofLiftV2Copy.primaryCta,
      secondaryCta: ReturnAfterProofLiftV2Copy.secondaryCta,
      promptLine: ReturnAfterProofCopy.promptLineForWatchTarget(targetType),
      targetType: targetType,
      confidenceLevel: proofConfidence.level,
      hasAnchor: hasAnchor,
      entryCount: entries.length,
      source: source,
    );
  }

  static bool shouldShow({
    required ReturnAfterProofLiftV2Result? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (ReturnAfterProofLiftV2Store.isDismissedToday) return false;
    if (!isReady && !isPostSave) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool _hasEligibleConfidence(
    ProofConfidenceCalibrationResult calibration,
  ) =>
      calibration.level == ProofConfidenceLevel.useful ||
      calibration.level == ProofConfidenceLevel.strong ||
      calibration.level == ProofConfidenceLevel.freshReturn;
}
