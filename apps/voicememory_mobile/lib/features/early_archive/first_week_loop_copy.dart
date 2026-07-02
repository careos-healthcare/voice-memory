/// Copy for the first-week return loop after first proof — Record ready only.
abstract final class FirstWeekLoopCopy {
  FirstWeekLoopCopy._();

  static const title = 'Record when this comes back';

  static const bodyFallback =
      'Next time this comes back, record a short moment. ArchiveMe compares it '
      'with your first proof and tracks stronger, softer, or about the same.';

  static const label = 'First week loop';

  static const footer =
      'ArchiveMe is watching whether this changes when it comes back.';

  static const recordCta = 'Record when it happens';

  static String bodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” comes back, record a short moment. '
      'ArchiveMe will compare it with your first proof.';
}
