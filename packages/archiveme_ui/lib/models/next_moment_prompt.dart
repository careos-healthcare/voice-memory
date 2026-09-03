/// Ladder stage for personalized next-moment prompts.
enum NextMomentPromptStage { one, two, three, four, fivePlus }

/// Navigation action for next-moment prompt CTAs.
enum NextMomentPromptAction { addMoment, viewEvidence, viewReview }

/// Tells users what kind of moment to capture next — evidence-based, not pressure.
class NextMomentPrompt {
  const NextMomentPrompt({
    required this.stage,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.primaryAction,
    this.secondaryCta,
    this.secondaryAction = NextMomentPromptAction.addMoment,
  });

  final NextMomentPromptStage stage;
  final String title;
  final String body;
  final String primaryCta;
  final String? secondaryCta;
  final NextMomentPromptAction primaryAction;
  final NextMomentPromptAction secondaryAction;

  /// Compact line for Archive Home "What to add next" section.
  String get nextActionSummary => title;
}
