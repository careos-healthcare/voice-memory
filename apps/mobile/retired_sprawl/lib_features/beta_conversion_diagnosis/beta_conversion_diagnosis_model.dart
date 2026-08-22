enum BetaConversionDiagnosisMetricId {
  firstSaveRate,
  secondSaveRate,
  thirdSaveRate,
  usefulFeedbackRate,
  tooVagueRate,
  alreadyKnewRate,
  notRelevantRate,
  returnAfterProofRate,
  paywallSeenAfterProofRate,
  purchaseCtaRate,
}

class BetaConversionDiagnosisItem {
  const BetaConversionDiagnosisItem({
    required this.metricId,
    required this.metricLabel,
    required this.message,
    required this.currentValue,
    required this.targetValue,
    required this.recommendedFixLabel,
  });

  final BetaConversionDiagnosisMetricId metricId;
  final String metricLabel;
  final String message;
  final double currentValue;
  final double targetValue;
  final String recommendedFixLabel;

  String get currentValueLabel => _formatRate(currentValue);

  String get targetValueLabel => _formatRate(targetValue);

  static String _formatRate(double value) {
    final percent = (value * 100).round();
    return '$percent%';
  }
}

class BetaConversionDiagnosisInput {
  const BetaConversionDiagnosisInput({
    this.recordScreenSeen = 0,
    this.firstMomentSaved = 0,
    this.secondMomentSaved = 0,
    this.thirdMomentSaved = 0,
    this.usefulCount = 0,
    this.tooVagueCount = 0,
    this.alreadyKnewCount = 0,
    this.notRelevantCount = 0,
    this.confirmedRepeatSeen = 0,
    this.returnedAfterFirstProof = 0,
    this.paywallSeenAfterProof = 0,
    this.purchaseTappedAfterProof = 0,
  });

  final int recordScreenSeen;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int thirdMomentSaved;
  final int usefulCount;
  final int tooVagueCount;
  final int alreadyKnewCount;
  final int notRelevantCount;
  final int confirmedRepeatSeen;
  final int returnedAfterFirstProof;
  final int paywallSeenAfterProof;
  final int purchaseTappedAfterProof;

  int get totalFeedbackCount =>
      usefulCount + tooVagueCount + alreadyKnewCount + notRelevantCount;
}

class BetaConversionDiagnosisResult {
  const BetaConversionDiagnosisResult({
    required this.title,
    required this.body,
    required this.diagnoses,
  });

  final String title;
  final String body;
  final List<BetaConversionDiagnosisItem> diagnoses;

  bool get hasDiagnoses => diagnoses.isNotEmpty;
}