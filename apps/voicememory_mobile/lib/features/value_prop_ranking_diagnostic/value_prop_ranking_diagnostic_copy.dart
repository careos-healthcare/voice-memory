/// Value proposition + ranking-need diagnostic copy — interpretation only.
abstract final class ValuePropRankingDiagnosticCopy {
  ValuePropRankingDiagnosticCopy._();

  static const title = 'What would make Pro worth it?';

  static const body =
      'Pro is the longer evidence trail. It shows whether a repeat keeps returning, '
      'changes, fades, or gets corrected over time.';

  static const strongerProofLine =
      'If you need stronger proof first, keep using free until ArchiveMe has a '
      'clearer repeat.';

  static const rankingLine =
      'If you want ranking, ArchiveMe should first confirm whether prioritisation '
      'would help you pay — without showing ranked lists yet.';

  static const valueLine =
      'The value is not more AI. It is seeing whether the same proof keeps '
      'changing over time.';

  static const question = 'What is blocking payment?';

  static const optionStrongerProof = 'I need stronger proof first';
  static const optionSeeOverTime = 'I need to see it over time';
  static const optionRankingBeforePaying = 'I need ranking before paying';
  static const optionPriceTooHigh = 'The price feels too high';
  static const optionWorthPaying = 'This is worth paying for';

  static const guardrail =
      'Investigate ranking only when payment is blocked specifically by '
      'prioritisation. Do not build ranked lists until the longer-trail value '
      'has been validated.';

  static const options = [
    optionStrongerProof,
    optionSeeOverTime,
    optionRankingBeforePaying,
    optionPriceTooHigh,
    optionWorthPaying,
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield strongerProofLine;
    yield rankingLine;
    yield valueLine;
    yield question;
    yield optionStrongerProof;
    yield optionSeeOverTime;
    yield optionRankingBeforePaying;
    yield optionPriceTooHigh;
    yield optionWorthPaying;
    yield guardrail;
  }
}
