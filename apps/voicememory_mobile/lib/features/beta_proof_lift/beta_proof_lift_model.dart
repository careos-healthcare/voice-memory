import 'beta_proof_lift_copy.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum BetaProofLiftSurface { timelineProofMoment, firstProofPayoff, patterns }

extension BetaProofLiftSurfaceAnalytics on BetaProofLiftSurface {
  String get analyticsValue => switch (this) {
    BetaProofLiftSurface.timelineProofMoment => 'timeline_proof_moment',
    BetaProofLiftSurface.firstProofPayoff => 'first_proof_payoff',
    BetaProofLiftSurface.patterns => 'patterns',
  };

  String get betaFeedbackSurfaceValue => switch (this) {
    BetaProofLiftSurface.timelineProofMoment => 'timeline_proof_moment',
    BetaProofLiftSurface.firstProofPayoff => 'first_proof_payoff',
    BetaProofLiftSurface.patterns => 'timeline_proof_moment',
  };
}

class BetaProofLiftSection {
  const BetaProofLiftSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class BetaProofLiftResult {
  const BetaProofLiftResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.surface,
    required this.title,
    required this.body,
    required this.sections,
    required this.deltaRows,
    required this.hasSafeAnchor,
    required this.hasDelta,
    required this.hasCurrentRelevance,
    required this.hasCorrection,
    required this.patternMatchQuality,
    required this.proofConfidenceCalibration,
  });

  factory BetaProofLiftResult.hidden({
    required String source,
    required BetaProofLiftSurface surface,
    required int entryCount,
  }) => BetaProofLiftResult(
    shouldShow: false,
    entryCount: entryCount,
    source: source,
    surface: surface,
    title: BetaProofLiftCopy.title,
    body: BetaProofLiftCopy.body,
    sections: const [],
    deltaRows: const [],
    hasSafeAnchor: false,
    hasDelta: false,
    hasCurrentRelevance: false,
    hasCorrection: false,
    patternMatchQuality: PatternMatchQualityResult.hidden(
      source: source,
      entryCount: entryCount,
    ),
    proofConfidenceCalibration: ProofConfidenceCalibrationResult.hidden(
      source: source,
      entryCount: entryCount,
    ),
  );

  final bool shouldShow;
  final int entryCount;
  final String source;
  final BetaProofLiftSurface surface;
  final String title;
  final String body;
  final List<BetaProofLiftSection> sections;
  final List<String> deltaRows;
  final bool hasSafeAnchor;
  final bool hasDelta;
  final bool hasCurrentRelevance;
  final bool hasCorrection;
  final PatternMatchQualityResult patternMatchQuality;
  final ProofConfidenceCalibrationResult proofConfidenceCalibration;

  bool get isWatchOnly =>
      proofConfidenceCalibration.isWatchOnly ||
      patternMatchQuality.shouldShowAsWatchOnly;

  List<String> get allCopyStrings => [
    title,
    body,
    ...sections.expand((section) => [section.heading, section.body]),
    ...deltaRows,
  ];
}
