/// Preserved proof value copy — why Pro keeps the longer evidence trail.
abstract final class PreservedProofValueCopy {
  PreservedProofValueCopy._();

  static const headline = 'Keep the proof you are building';

  static const body =
      'ArchiveMe is useful because your repeats build evidence over time. Pro keeps '
      'the longer trail so you can see what returned, changed, faded, or was corrected.';

  static const freeLine = 'Free shows the first useful proof.';

  static const proLine = 'Pro keeps the proof trail after that.';

  static const whyPayLine =
      'You are paying to preserve the trail, not to get more chat or more AI.';

  static const lossLine =
      'Without the longer trail, you may see the first proof but lose the story of '
      'what happened next.';

  static const valueLine =
      'The value is not storage. The value is seeing what your past keeps proving.';

  static const repeatLine =
      'When something repeats, ArchiveMe can show whether it stayed the same, softened, '
      'strengthened, faded, or was corrected.';

  static const guardrail =
      'Preserved proof value must create clarity, not pressure. Do not use fear, '
      'urgency tricks, streaks, or scarcity.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield freeLine;
    yield proLine;
    yield whyPayLine;
    yield lossLine;
    yield valueLine;
    yield repeatLine;
  }
}