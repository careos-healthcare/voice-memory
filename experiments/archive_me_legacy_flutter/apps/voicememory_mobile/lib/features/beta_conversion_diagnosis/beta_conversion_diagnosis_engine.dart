import '../beta_activation/beta_activation_summary_tracker.dart';
import '../testflight_metrics/testflight_metrics_engine.dart';
import 'beta_conversion_diagnosis_copy.dart';
import 'beta_conversion_diagnosis_model.dart';

/// Builds beta conversion diagnoses from local metadata counts only.
abstract final class BetaConversionDiagnosisEngine {
  BetaConversionDiagnosisEngine._();

  static const firstSaveTarget = 0.50;
  static const secondSaveTarget = 0.30;
  static const thirdSaveTarget = 0.20;
  static const usefulFeedbackTarget = 0.30;
  static const returnAfterProofTarget = 0.25;
  static const paywallSeenAfterProofTarget = 0.35;
  static const purchaseCtaTarget = 0.05;

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static Future<BetaConversionDiagnosisResult> build() async {
    final input = await loadInput();
    return buildFromInput(input);
  }

  static Future<BetaConversionDiagnosisInput> loadInput() async {
    final metricsInput = await TestFlightMetricsEngine.loadInput();
    final loaded = await BetaActivationSummaryTracker.loadAll();

    return BetaConversionDiagnosisInput(
      recordScreenSeen: loaded.loop.recordScreenSeen,
      firstMomentSaved: metricsInput.firstMomentSaved,
      secondMomentSaved: metricsInput.secondMomentSaved,
      thirdMomentSaved: metricsInput.thirdMomentSaved,
      usefulCount: metricsInput.usefulCount,
      tooVagueCount: metricsInput.tooVagueCount,
      alreadyKnewCount: metricsInput.alreadyKnewCount,
      notRelevantCount: metricsInput.notRelevantCount,
      confirmedRepeatSeen: loaded.loop.confirmedRepeatSeen > 0
          ? loaded.loop.confirmedRepeatSeen
          : metricsInput.firstProofReached,
      returnedAfterFirstProof: metricsInput.returnedAfterFirstProof,
      paywallSeenAfterProof: loaded.loop.paywallSeen,
      purchaseTappedAfterProof: metricsInput.purchaseTapped > 0
          ? metricsInput.purchaseTapped
          : (metricsInput.sessionPaywallIntent ? 1 : 0),
    );
  }

  static BetaConversionDiagnosisResult buildFromInput(
    BetaConversionDiagnosisInput input,
  ) {
    final diagnoses = <BetaConversionDiagnosisItem>[];

    final firstSaveRate = _rate(input.firstMomentSaved, input.recordScreenSeen);
    final secondSaveRate = _rate(
      input.secondMomentSaved,
      input.firstMomentSaved,
    );
    final thirdSaveRate = _rate(
      input.thirdMomentSaved,
      input.secondMomentSaved,
    );
    final usefulFeedbackRate = _rate(
      input.usefulCount,
      input.totalFeedbackCount,
    );
    final tooVagueRate = _rate(input.tooVagueCount, input.totalFeedbackCount);
    final alreadyKnewRate = _rate(
      input.alreadyKnewCount,
      input.totalFeedbackCount,
    );
    final notRelevantRate = _rate(
      input.notRelevantCount,
      input.totalFeedbackCount,
    );
    final returnAfterProofRate = _rate(
      input.returnedAfterFirstProof,
      input.confirmedRepeatSeen,
    );
    final paywallSeenAfterProofRate = _rate(
      input.paywallSeenAfterProof,
      input.confirmedRepeatSeen,
    );
    final purchaseCtaRate = _rate(
      input.purchaseTappedAfterProof,
      input.paywallSeenAfterProof,
    );

    if (firstSaveRate < firstSaveTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.firstSaveRate,
          metricLabel: BetaConversionDiagnosisCopy.metricFirstSaveRate,
          message: BetaConversionDiagnosisCopy.firstCaptureUnclear,
          currentValue: firstSaveRate,
          targetValue: firstSaveTarget,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixFirstCapture,
        ),
      );
    }

    if (secondSaveRate < secondSaveTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.secondSaveRate,
          metricLabel: BetaConversionDiagnosisCopy.metricSecondSaveRate,
          message: BetaConversionDiagnosisCopy.returnReasonWeak,
          currentValue: secondSaveRate,
          targetValue: secondSaveTarget,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixReturnPrompt,
        ),
      );
    }

    if (thirdSaveRate < thirdSaveTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.thirdSaveRate,
          metricLabel: BetaConversionDiagnosisCopy.metricThirdSaveRate,
          message: BetaConversionDiagnosisCopy.notReachingProof,
          currentValue: thirdSaveRate,
          targetValue: thirdSaveTarget,
          recommendedFixLabel:
              BetaConversionDiagnosisCopy.fixThreeMomentCompletion,
        ),
      );
    }

    if (input.totalFeedbackCount > 0 &&
        usefulFeedbackRate < usefulFeedbackTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.usefulFeedbackRate,
          metricLabel: BetaConversionDiagnosisCopy.metricUsefulFeedbackRate,
          message: BetaConversionDiagnosisCopy.timelineNotUseful,
          currentValue: usefulFeedbackRate,
          targetValue: usefulFeedbackTarget,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixProofSpecificity,
        ),
      );
    }

    if (input.totalFeedbackCount > 0 && tooVagueRate > usefulFeedbackRate) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.tooVagueRate,
          metricLabel: BetaConversionDiagnosisCopy.metricTooVagueRate,
          message: BetaConversionDiagnosisCopy.specificityWeak,
          currentValue: tooVagueRate,
          targetValue: usefulFeedbackRate,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixProofSpecificity,
        ),
      );
    }

    if (input.totalFeedbackCount > 0 && alreadyKnewRate > usefulFeedbackRate) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.alreadyKnewRate,
          metricLabel: BetaConversionDiagnosisCopy.metricAlreadyKnewRate,
          message: BetaConversionDiagnosisCopy.changeDeltaWeak,
          currentValue: alreadyKnewRate,
          targetValue: usefulFeedbackRate,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixChangeDeltaProof,
        ),
      );
    }

    if (input.totalFeedbackCount > 0 && notRelevantRate > usefulFeedbackRate) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.notRelevantRate,
          metricLabel: BetaConversionDiagnosisCopy.metricNotRelevantRate,
          message: BetaConversionDiagnosisCopy.relevanceWeak,
          currentValue: notRelevantRate,
          targetValue: usefulFeedbackRate,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixCurrentRelevance,
        ),
      );
    }

    if (input.confirmedRepeatSeen > 0 &&
        returnAfterProofRate < returnAfterProofTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.returnAfterProofRate,
          metricLabel: BetaConversionDiagnosisCopy.metricReturnAfterProofRate,
          message: BetaConversionDiagnosisCopy.returnAfterProofWeak,
          currentValue: returnAfterProofRate,
          targetValue: returnAfterProofTarget,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixReturnAfterProof,
        ),
      );
    }

    if (input.confirmedRepeatSeen > 0 &&
        paywallSeenAfterProofRate < paywallSeenAfterProofTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.paywallSeenAfterProofRate,
          metricLabel:
              BetaConversionDiagnosisCopy.metricPaywallSeenAfterProofRate,
          message: BetaConversionDiagnosisCopy.proBridgeHidden,
          currentValue: paywallSeenAfterProofRate,
          targetValue: paywallSeenAfterProofTarget,
          recommendedFixLabel:
              BetaConversionDiagnosisCopy.fixProBridgeVisibility,
        ),
      );
    }

    if (input.paywallSeenAfterProof > 0 &&
        purchaseCtaRate < purchaseCtaTarget) {
      diagnoses.add(
        _item(
          metricId: BetaConversionDiagnosisMetricId.purchaseCtaRate,
          metricLabel: BetaConversionDiagnosisCopy.metricPurchaseCtaRate,
          message: BetaConversionDiagnosisCopy.paidReasonWeak,
          currentValue: purchaseCtaRate,
          targetValue: purchaseCtaTarget,
          recommendedFixLabel: BetaConversionDiagnosisCopy.fixPaywallPaidReason,
        ),
      );
    }

    return BetaConversionDiagnosisResult(
      title: BetaConversionDiagnosisCopy.title,
      body: BetaConversionDiagnosisCopy.body,
      diagnoses: diagnoses,
    );
  }

  static BetaConversionDiagnosisItem _item({
    required BetaConversionDiagnosisMetricId metricId,
    required String metricLabel,
    required String message,
    required double currentValue,
    required double targetValue,
    required String recommendedFixLabel,
  }) {
    return BetaConversionDiagnosisItem(
      metricId: metricId,
      metricLabel: metricLabel,
      message: message,
      currentValue: currentValue,
      targetValue: targetValue,
      recommendedFixLabel: recommendedFixLabel,
    );
  }

  static double _rate(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }
}
