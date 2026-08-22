/// Beta expansion proof copy — required signals before product expansion.
abstract final class BetaExpansionProofCopy {
  BetaExpansionProofCopy._();

  static const headline = 'Beta expansion proof gate';

  static const body =
      'Do not expand product surface until beta proof thresholds pass. Metrics only — '
      'not new visible features.';

  static const requiredBeforeExpansion = <String>[
    '20 invites',
    '10 installs',
    '10 first saved moments',
    '5 users with 3 real moments',
    '3 day-2 returns',
    '2 willingness-to-pay signals for keeping the longer proof trail',
  ];

  static const retentionMetricsOnly = <String>[
    'day-2 return',
    'day-7 return',
    'moments across 3+ days',
    'review ritual',
    'copied milestone',
    'export usage',
  ];

  static const guardrail =
      'Retention proof stays metrics-only. Do not turn expansion metrics into new '
      'visible product surfaces before beta proof passes.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield guardrail;
    yield* requiredBeforeExpansion;
    yield* retentionMetricsOnly;
  }
}