/// Product language consistency guard copy — proof-trail language wins.
abstract final class ProductLanguageConsistencyGuardCopy {
  ProductLanguageConsistencyGuardCopy._();

  static const headline = 'Product language consistency guard';

  static const body =
      'Make proof-trail language win over dashboard, story, storage, and report-first framing.';

  static const publicPromise =
      'When something repeats, save one real moment. ArchiveMe compares it later.';

  static const preferredLanguageLine =
      'Prefer repeat, proof, proof trail, longer proof trail, returns, changes, fades, '
      'corrected, one real sentence, compares later, and the public promise.';

  static const riskyLanguageLine =
      'Risky: full timeline, longer story, dashboard, archive health score, memory quality '
      'score, report as primary value, storage, second brain, life operating system, '
      'assistant-style ai, chatgpt replacement, more ai, unlimited answers.';

  static const blockLine =
      'High-risk product language detected. Rewrite with proof-trail language.';

  static const warnLine =
      'Risky product language detected. Prefer proof-trail framing in visible copy.';

  static const guardrail =
      'Copy guard only. Do not change all copy blindly. Fix high-risk visible copy in the '
      'first journey or Pro promise. No new features.';

  static Iterable<String> allVisibleStrings() sync* {
    yield publicPromise;
    yield headline;
    yield body;
    yield preferredLanguageLine;
    yield riskyLanguageLine;
    yield blockLine;
    yield warnLine;
    yield guardrail;
  }
}