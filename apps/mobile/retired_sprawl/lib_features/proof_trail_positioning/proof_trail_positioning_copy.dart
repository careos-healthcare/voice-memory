/// Proof trail positioning copy — not chat, not storage, meaningful resurfacing.
abstract final class ProofTrailPositioningCopy {
  ProofTrailPositioningCopy._();

  static const headline = 'Not a chat box. A proof trail.';

  static const body =
      'ArchiveMe is not where you store everything. It is where you save small real '
      'moments so your archive can show what keeps coming back.';

  static const notChatLine =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const notStorageLine =
      'Notes store what happened. ArchiveMe checks what returns.';

  static const proofTrailLine =
      'A proof trail shows the first repeat, why it appeared, what you confirmed or '
      'corrected, and what changed later.';

  static const resurfacingLine =
      'The value is meaningful resurfacing — not more notes, more dashboards, or more AI.';

  static const saveRepeatLine =
      'Use ArchiveMe when something repeats and you want your future self to see '
      'the pattern.';

  static const lowEffortLine =
      'One real sentence is enough. No daily homework. No dashboard to maintain.';

  static const proLine =
      'Free shows the first useful proof. Pro keeps the longer proof trail.';

  static const guardrail =
      'ArchiveMe must be positioned as a low-effort proof trail, not a chat box, '
      'storage app, second brain, or dashboard to maintain.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield notChatLine;
    yield notStorageLine;
    yield proofTrailLine;
    yield resurfacingLine;
    yield saveRepeatLine;
    yield lowEffortLine;
    yield proLine;
  }
}