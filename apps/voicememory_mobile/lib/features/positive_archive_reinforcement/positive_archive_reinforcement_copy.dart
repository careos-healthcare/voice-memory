/// Positive archive reinforcement copy — evidence capture, not gamification.
abstract final class PositiveArchiveReinforcementCopy {
  PositiveArchiveReinforcementCopy._();

  static const headline = 'Saved for your archive';

  static const body =
      'That one moment is enough. ArchiveMe now has something real to compare later.';

  static const noticedLine =
      'You noticed it and saved it. That matters.';

  static const smallMomentLine =
      'Small moments are how the trail becomes clear.';

  static const repeatRelatedLine =
      'This may help ArchiveMe see whether the repeat is returning, changing, '
      'fading, or getting corrected.';

  static const notEnoughProofLine =
      'No need to force more. ArchiveMe works from real moments over time.';

  static const noHomeworkLine =
      'No daily homework. No streak. No mind-map maintenance.';

  static const chatDifferenceLine =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const guardrail =
      'Reinforce evidence capture without creating streaks, daily pressure, advice, '
      'therapy, or gamified habits.';

  static const firstMomentSavedMessage =
      'Saved. One real moment is enough to start your archive.';

  static const repeatRelatedMomentSavedMessage =
      'Saved. This may help ArchiveMe see whether the repeat is returning, '
      'changing, fading, or getting corrected.';

  static const notEnoughProofYetMessage =
      'Saved. No need to force more — ArchiveMe works from real moments over time.';

  static const simpleMomentSavedMessage =
      'Saved. This gives your archive something real to compare later.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield noticedLine;
    yield smallMomentLine;
    yield repeatRelatedLine;
    yield notEnoughProofLine;
    yield noHomeworkLine;
    yield chatDifferenceLine;
    yield firstMomentSavedMessage;
    yield repeatRelatedMomentSavedMessage;
    yield notEnoughProofYetMessage;
    yield simpleMomentSavedMessage;
  }
}
