/// Change trail clarity copy — explain what one repeat proves over time.
abstract final class ChangeTrailClarityCopy {
  ChangeTrailClarityCopy._();

  static const title = 'What the trail shows';

  static const body =
      'After the first proof, ArchiveMe keeps watching the same repeat. The trail '
      'shows whether it comes back, changes shape, gets softer, gets stronger, '
      'fades, or gets corrected.';

  static const returnsLine =
      'Returns: the same repeat appears again.';

  static const changesLine =
      'Changes: the repeat shows up in a slightly different way.';

  static const softensLine =
      'Softens: the repeat is still there, but less intense or easier to notice.';

  static const strengthensLine =
      'Strengthens: the repeat appears more clearly or more often.';

  static const fadesLine =
      'Fades: the repeat stops showing up as much.';

  static const correctedLine =
      'Corrected: you marked the proof as too vague or not relevant, so ArchiveMe '
      'does not treat it as useful proof.';

  static const proLine =
      'Free shows the first useful proof. Pro keeps this change trail over time.';

  static const valueLine =
      'You are paying to keep seeing what happens to the same repeat, not for more AI.';

  static const guardrail =
      'Do not add more proof or ranking to explain the trail. Explain what happens '
      'to one repeat over time.';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield returnsLine;
    yield changesLine;
    yield softensLine;
    yield strengthensLine;
    yield fadesLine;
    yield correctedLine;
    yield proLine;
    yield valueLine;
    yield guardrail;
  }
}
