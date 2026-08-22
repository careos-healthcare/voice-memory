/// Low / medium / high signal strength for choice and pressure reads.
enum ProveEnoughLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case ProveEnoughLevel.low:
        return 'Low';
      case ProveEnoughLevel.medium:
        return 'Medium';
      case ProveEnoughLevel.high:
        return 'High';
    }
  }
}

/// Post-recording prove_enough payoff derived from one saved moment.
class ProveEnoughPostRecordModel {
  const ProveEnoughPostRecordModel({
    required this.entryId,
    required this.loopModeId,
    required this.pressureLevel,
    required this.choiceLevel,
    required this.restGuiltPresent,
    required this.enoughnessScore,
    required this.whatLookedLikeChoice,
    required this.whatLookedLikePressure,
    required this.imaginedStopCostPrompt,
    required this.detectedStopCostTags,
    required this.evidencePhrases,
    this.transcriptWeak = false,
  });

  final String entryId;
  final String loopModeId;
  final ProveEnoughLevel pressureLevel;
  final ProveEnoughLevel choiceLevel;
  final bool restGuiltPresent;
  final int enoughnessScore;
  final List<String> whatLookedLikeChoice;
  final List<String> whatLookedLikePressure;
  final String imaginedStopCostPrompt;
  final List<String> detectedStopCostTags;
  final List<String> evidencePhrases;
  final bool transcriptWeak;

  /// 0–35 mostly choice; 36–65 mixed; 66–100 pressure looks high.
  String get enoughnessLabel {
    if (transcriptWeak) {
      return 'ArchiveMe needs a clearer moment to score this well.';
    }
    if (enoughnessScore <= 35) return 'Mostly choice';
    if (enoughnessScore <= 65) return 'Mixed choice and pressure';
    return 'Pressure looks high';
  }

  String get restGuiltLabel => restGuiltPresent ? 'Present' : 'Not clear';
}