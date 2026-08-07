import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../return_after_proof/return_after_proof_model.dart';

class ReturnAfterProofLiftV2Result {
  const ReturnAfterProofLiftV2Result({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.watchLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.promptLine,
    required this.targetType,
    required this.confidenceLevel,
    required this.hasAnchor,
    required this.entryCount,
    required this.source,
  });

  static ReturnAfterProofLiftV2Result hidden({
    required String source,
    required int entryCount,
  }) => ReturnAfterProofLiftV2Result(
    shouldShow: false,
    title: '',
    body: '',
    watchLine: '',
    primaryCta: '',
    secondaryCta: '',
    promptLine: '',
    targetType: ReturnAfterProofWatchTargetType.returnedAgain,
    confidenceLevel: ProofConfidenceLevel.watchOnly,
    hasAnchor: false,
    entryCount: entryCount,
    source: source,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String watchLine;
  final String primaryCta;
  final String secondaryCta;
  final String promptLine;
  final ReturnAfterProofWatchTargetType targetType;
  final ProofConfidenceLevel confidenceLevel;
  final bool hasAnchor;
  final int entryCount;
  final String source;
}
