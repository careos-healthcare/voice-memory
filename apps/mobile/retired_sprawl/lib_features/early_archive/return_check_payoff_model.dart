/// Comparison outcome for a return against the first proof.
enum ReturnCheckPayoffComparisonState {
  softer,
  stronger,
  same,
  changed,
  unknown;

  String get analyticsValue => name;
}

/// Post-save payoff after a related return at entry four or later.
class ReturnCheckPayoff {
  const ReturnCheckPayoff({
    required this.state,
    required this.title,
    required this.body,
    required this.evidenceLabel,
    required this.footer,
    required this.hasPhrase,
    required this.hasConfirmedRepeat,
    required this.usesPhraseBody,
  });

  final ReturnCheckPayoffComparisonState state;
  final String title;
  final String body;
  final String evidenceLabel;
  final String footer;
  final bool hasPhrase;
  final bool hasConfirmedRepeat;
  final bool usesPhraseBody;
}