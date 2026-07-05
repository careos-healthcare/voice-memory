/// User truth rating for a first proof moment.
enum FirstProofTruthAnswer {
  yes,
  sortOf,
  no,
}

/// Local first-proof truth follow-up state for one proof key.
class FirstProofTruthPrompt {
  const FirstProofTruthPrompt({
    required this.proofKey,
    required this.hasSnippets,
    this.existingAnswer,
  });

  final String proofKey;
  final bool hasSnippets;
  final FirstProofTruthAnswer? existingAnswer;

  bool get hasAnswered => existingAnswer != null;
}
