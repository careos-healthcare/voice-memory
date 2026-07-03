/// Post-save payoff after a strong confirmed repeat at entry 3.
class FirstProofMoment {
  const FirstProofMoment({
    required this.primaryLabel,
    required this.title,
    required this.body,
    required this.evidenceLabel,
    required this.evidencePhrases,
    required this.whyLine,
    required this.nextLine,
    required this.hasStrongEvidence,
    required this.usesPhraseBody,
  });

  final String primaryLabel;
  final String title;
  final String body;
  final String evidenceLabel;
  final List<String> evidencePhrases;
  final String whyLine;
  final String nextLine;
  final bool hasStrongEvidence;
  final bool usesPhraseBody;
}
