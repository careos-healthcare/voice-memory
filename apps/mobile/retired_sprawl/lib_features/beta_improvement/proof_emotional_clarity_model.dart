/// Proof emotional clarity display variant — cautious, evidence-based only.
enum ProofEmotionalClarityVariant {
  strongRepeat,
  softened,
  changed,
  repeated,
  faded,
  watchOnly,
}

/// Gated proof card content when the proof emotional clarity branch is active.
class ProofEmotionalClarityDisplay {
  const ProofEmotionalClarityDisplay({
    required this.variant,
    required this.headline,
    this.subheadline,
    this.evidenceLine,
    this.whatCameBackBody,
    this.whatChangedBody,
    this.whyItMightMatterBody,
    this.showCorrectionRow = false,
  });

  final ProofEmotionalClarityVariant variant;
  final String headline;
  final String? subheadline;
  final String? evidenceLine;
  final String? whatCameBackBody;
  final String? whatChangedBody;
  final String? whyItMightMatterBody;
  final bool showCorrectionRow;

  bool get showSections =>
      (whatCameBackBody?.trim().isNotEmpty ?? false) ||
      (whatChangedBody?.trim().isNotEmpty ?? false) ||
      (whyItMightMatterBody?.trim().isNotEmpty ?? false);
}