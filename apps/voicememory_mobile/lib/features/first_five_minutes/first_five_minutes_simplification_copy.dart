/// First-five-minutes simplification copy — save one repeat, compare later.
abstract final class FirstFiveMinutesSimplificationCopy {
  FirstFiveMinutesSimplificationCopy._();

  static const headline = 'Save one repeat';

  static const body =
      'ArchiveMe is simple: when something repeats, save one real sentence. Your '
      'archive compares it later.';

  static const oneLinePositioning =
      'ArchiveMe shows what keeps coming back.';

  static const whenToUseLine =
      'Use it when you notice: I have felt this before, done this before, avoided '
      'this before, or checked this before.';

  static const oneSentenceLine = 'One sentence is enough.';

  static const savedMattersLine =
      'Saved moments give your archive something real to compare.';

  static const whatHappensNextLine =
      'After enough real moments, ArchiveMe can show the first useful proof.';

  static const firstProofPreviewLine = whatHappensNextLine;

  static const notNowLine =
      'No reports, dashboards, action items, or context work needed now.';

  static const notChatLine =
      'This is not chat. It is a proof trail.';

  static const notStorageLine =
      'This is not where you store everything. It is where you save what repeats.';

  static const guardrail =
      'The first five minutes must focus only on saving one repeat and understanding '
      'that ArchiveMe compares it later.';

  static bool previewImpliesProofExists(String text) {
    final lower = text.toLowerCase();
    return lower.contains('proof exists') ||
        lower.contains('your proof is ready') ||
        lower.contains('first proof appeared') ||
        lower.contains('proof is here');
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield oneLinePositioning;
    yield whenToUseLine;
    yield oneSentenceLine;
    yield savedMattersLine;
    yield whatHappensNextLine;
    yield firstProofPreviewLine;
    yield notNowLine;
    yield notChatLine;
    yield notStorageLine;
    yield guardrail;
  }
}
