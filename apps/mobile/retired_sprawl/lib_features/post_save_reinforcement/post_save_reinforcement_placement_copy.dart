/// Post-save reinforcement placement copy — reward capture, not pressure.
abstract final class PostSaveReinforcementPlacementCopy {
  PostSaveReinforcementPlacementCopy._();

  static const headline = 'Saved for your archive';

  static const body =
      'That one moment is enough. ArchiveMe now has something real to compare later.';

  static const firstMomentLine =
      'Saved. One real moment is enough to start your archive.';

  static const simpleMomentLine =
      'Saved. This gives your archive something real to compare later.';

  static const repeatRelatedLine =
      'Saved. This may help ArchiveMe see whether that repeat is returning, '
      'changing, fading, or getting corrected.';

  static const notEnoughProofLine =
      'Saved. No need to force more — ArchiveMe works from real moments over time.';

  static const noPressureLine =
      'No daily homework. No streak. No pressure to record more.';

  static const nextLine =
      'You can stop here, or save another moment only if something real is still on your mind.';

  static const guardrail =
      'Post-save reinforcement must reward evidence capture without creating streaks, '
      'pressure, advice, therapy, or a requirement to record more.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield firstMomentLine;
    yield simpleMomentLine;
    yield repeatRelatedLine;
    yield notEnoughProofLine;
    yield noPressureLine;
    yield nextLine;
  }
}