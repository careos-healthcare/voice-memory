/// Conservative strength label — no percentages or AI confidence language.
enum InsightStrengthLabel {
  earlySignal,
  possibleRepeat,
  gettingClearer,
  strongPattern,
}

extension InsightStrengthLabelCopy on InsightStrengthLabel {
  String get displayLabel => switch (this) {
    InsightStrengthLabel.earlySignal => 'Early signal',
    InsightStrengthLabel.possibleRepeat => 'Possible repeat',
    InsightStrengthLabel.gettingClearer => 'Getting clearer',
    InsightStrengthLabel.strongPattern => 'Strong pattern',
  };
}

class InsightStrength {
  const InsightStrength({
    required this.label,
    required this.whySuggested,
    required this.evidenceChips,
  });

  final InsightStrengthLabel label;
  final String whySuggested;
  final List<String> evidenceChips;
}
