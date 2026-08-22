/// Copy for the first-week return loop after first proof — Record ready only.
abstract final class FirstWeekLoopCopy {
  FirstWeekLoopCopy._();

  static const title = 'Record when this comes back';

  static const bodyFallback =
      'Next time it returns, record a short moment. ArchiveMe compares it with your first proof.';

  static const label = 'First week loop';

  static const footer =
      'The evidence timeline grows as ArchiveMe compares returns over time.';

  static const recordCta = 'Record when it happens';

  static String bodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” comes back, record a short moment. '
      'ArchiveMe will compare it with your first proof.';
}