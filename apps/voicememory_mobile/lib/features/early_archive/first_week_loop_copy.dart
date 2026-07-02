/// Copy for the first-week return loop after first proof — Record ready only.
abstract final class FirstWeekLoopCopy {
  FirstWeekLoopCopy._();

  static const title = 'Record when this comes back';

  static const bodyFallback =
      'ArchiveMe tracks what happens when this comes back. Record the next return so ArchiveMe can compare stronger, softer, or about the same since your first proof.';

  static const label = 'First week loop';

  static const footer =
      'ArchiveMe is watching whether this changes when it comes back.';

  static const recordCta = 'Record when it happens';

  static String bodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” happens, record it. ArchiveMe will compare it with your first proof and track what changed.';
}
