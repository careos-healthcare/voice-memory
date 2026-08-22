import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_copy.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_model.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_store.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';

abstract final class ProUnderstandingLiftEngine {
  ProUnderstandingLiftEngine._();

  static const proUnderstandingTarget = 0.20;

  static ProUnderstandingLiftResult build({
    required ProUnderstandingLiftVisibilityInput input,
  }) {
    final shouldShow = shouldShowCard(input: input);
    return ProUnderstandingLiftResult(
      shouldShow: shouldShow,
      title: ProUnderstandingLiftCopy.title,
      body: ProUnderstandingLiftCopy.body,
      bullets: ProUnderstandingLiftCopy.bullets,
      supportLine: ProUnderstandingLiftCopy.supportLine,
      primaryCta: ProUnderstandingLiftCopy.primaryCta,
      secondaryCta: ProUnderstandingLiftCopy.secondaryCta,
      source: input.source,
      surface: input.surface,
      entryCount: input.entryCount,
      hasUsefulProof:
          input.hasUsefulProof || _hasEligibleConfidence(input.confidenceLevel),
      hasPaywallSeen: input.hasProEngagement,
    );
  }

  static bool shouldShowCard({
    required ProUnderstandingLiftVisibilityInput input,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (ProUnderstandingLiftStore.isDismissedToday) return false;
    if (input.isPro) return false;
    if (input.hasProEngagement) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasUsefulProof &&
        !_hasEligibleConfidence(input.confidenceLevel)) {
      return false;
    }
    if (input.feedbackState == ProofQualityFeedbackState.tooVague ||
        input.feedbackState == ProofQualityFeedbackState.notRelevant) {
      return false;
    }
    if (input.feedbackState == ProofQualityFeedbackState.alreadyKnewThis &&
        !input.hasFreshReturnAfterCorrection &&
        !input.hasChangeAnchor) {
      return false;
    }
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.isPostSaveDegradedState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool _hasEligibleConfidence(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.freshReturn;

  static String statusLabel({required bool visible}) =>
      visible ? 'Eligible after useful proof' : 'Hidden';

  static bool isProUnderstandingWeak({
    required int understandsProYesMaybe,
    required int understandsProSurveyResponses,
  }) {
    if (understandsProSurveyResponses <= 0) return false;
    return understandsProYesMaybe / understandsProSurveyResponses <
        proUnderstandingTarget;
  }

  static String resolveCurrentDiagnosis({
    required bool firstSessionCaptureWeak,
    required bool proUnderstandingWeak,
  }) {
    if (firstSessionCaptureWeak) {
      return ProUnderstandingLiftCopy.diagnosisFixFirstSessionCapture;
    }
    if (proUnderstandingWeak) {
      return ProUnderstandingLiftCopy.diagnosisFixProUnderstanding;
    }
    return ProUnderstandingLiftCopy.diagnosisReadyForMoreTesters;
  }
}