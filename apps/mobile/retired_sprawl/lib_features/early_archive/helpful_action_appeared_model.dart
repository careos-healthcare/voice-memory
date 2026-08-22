/// Built helpful-action payoff — grounded in the user's own words only.
class HelpfulActionAppeared {
  const HelpfulActionAppeared({
    required this.title,
    required this.body,
    required this.evidenceLabel,
    required this.footer,
    required this.chipLabel,
    required this.usesActionPhrase,
    required this.hasConfirmedRepeat,
    this.actionPhrase,
  });

  final String title;
  final String body;
  final String evidenceLabel;
  final String footer;
  final String chipLabel;
  final bool usesActionPhrase;
  final bool hasConfirmedRepeat;
  final String? actionPhrase;
}