import '../chat_differentiation/chat_differentiation_model.dart';

/// One quoted line pulled from a saved entry — never invented.
class FirstProofEvidenceSnippet {
  const FirstProofEvidenceSnippet({
    required this.label,
    required this.quote,
  });

  final String label;
  final String quote;
}

enum FirstProofPayoffVariant {
  strongWithSnippets,
  fallbackPhraseOnly,
}

/// Emotional payoff after the third related save — metadata for UI only.
class FirstProofPayoff {
  const FirstProofPayoff({
    required this.variant,
    required this.headline,
    required this.subhead,
    required this.groundedPhrase,
    required this.evidenceLabel,
    required this.snippets,
    required this.meaningLine,
    required this.returnHook,
    required this.hasStrongEvidence,
    required this.canShowPatternDetail,
    this.differentiationLine,
    this.timelineRows = const [],
  });

  final FirstProofPayoffVariant variant;
  final String headline;
  final String subhead;
  final String groundedPhrase;
  final String evidenceLabel;
  final List<FirstProofEvidenceSnippet> snippets;
  final String meaningLine;
  final String returnHook;
  final bool hasStrongEvidence;
  final bool canShowPatternDetail;
  final String? differentiationLine;
  final List<ChatDifferentiationTimelineRow> timelineRows;

  bool get hasSnippets => snippets.length >= 2;

  bool get showDifferentiation =>
      differentiationLine != null && differentiationLine!.trim().isNotEmpty;
}
