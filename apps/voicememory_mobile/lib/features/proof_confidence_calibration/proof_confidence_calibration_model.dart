import 'proof_confidence_calibration_copy.dart';

enum ProofConfidenceLevel {
  watchOnly,
  emerging,
  useful,
  strong,
  corrected,
  freshReturn,
}

extension ProofConfidenceLevelAnalytics on ProofConfidenceLevel {
  String get analyticsValue => switch (this) {
    ProofConfidenceLevel.watchOnly => 'watch_only',
    ProofConfidenceLevel.emerging => 'emerging',
    ProofConfidenceLevel.useful => 'useful',
    ProofConfidenceLevel.strong => 'strong',
    ProofConfidenceLevel.corrected => 'corrected',
    ProofConfidenceLevel.freshReturn => 'fresh_return',
  };
}

class ProofConfidenceCalibrationResult {
  const ProofConfidenceCalibrationResult({
    required this.shouldCalibrate,
    required this.entryCount,
    required this.source,
    required this.level,
    required this.primaryCopy,
    required this.displayCopy,
    required this.hasSafeAnchor,
    required this.hasMatchQuality,
    required this.hasCorrection,
    required this.hasFreshReturn,
    this.leadCopy,
  });

  factory ProofConfidenceCalibrationResult.hidden({
    required String source,
    required int entryCount,
  }) => ProofConfidenceCalibrationResult(
    shouldCalibrate: false,
    entryCount: entryCount,
    source: source,
    level: ProofConfidenceLevel.watchOnly,
    primaryCopy: ProofConfidenceCalibrationCopy.watchOnly,
    displayCopy: ProofConfidenceCalibrationCopy.watchOnly,
    hasSafeAnchor: false,
    hasMatchQuality: false,
    hasCorrection: false,
    hasFreshReturn: false,
  );

  final bool shouldCalibrate;
  final int entryCount;
  final String source;
  final ProofConfidenceLevel level;
  final String primaryCopy;
  final String? leadCopy;
  final String displayCopy;
  final bool hasSafeAnchor;
  final bool hasMatchQuality;
  final bool hasCorrection;
  final bool hasFreshReturn;

  bool get isWatchOnly => level == ProofConfidenceLevel.watchOnly;
  bool get isProofLevel =>
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.freshReturn;
}
