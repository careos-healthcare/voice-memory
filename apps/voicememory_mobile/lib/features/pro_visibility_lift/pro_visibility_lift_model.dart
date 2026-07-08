import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../proof_quality_response/proof_quality_response_model.dart';
import 'pro_visibility_lift_copy.dart';

class ProVisibilityLiftResult {
  const ProVisibilityLiftResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.confidenceLevel,
    required this.feedbackState,
    required this.hasPaywallSeen,
  });

  static ProVisibilityLiftResult hidden({
    required String source,
    required ProVisibilityLiftSurface surface,
    required int entryCount,
  }) =>
      ProVisibilityLiftResult(
        shouldShow: false,
        title: '',
        body: '',
        primaryCta: '',
        secondaryCta: '',
        source: source,
        surface: surface,
        entryCount: entryCount,
        confidenceLevel: ProofConfidenceLevel.watchOnly,
        feedbackState: ProofQualityFeedbackState.none,
        hasPaywallSeen: false,
      );

  final bool shouldShow;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final String source;
  final ProVisibilityLiftSurface surface;
  final int entryCount;
  final ProofConfidenceLevel confidenceLevel;
  final ProofQualityFeedbackState feedbackState;
  final bool hasPaywallSeen;
}
