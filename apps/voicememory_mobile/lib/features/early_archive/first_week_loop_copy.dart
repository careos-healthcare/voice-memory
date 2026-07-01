/// Copy for the first-week return loop after first proof — Record ready only.
abstract final class FirstWeekLoopCopy {
  FirstWeekLoopCopy._();

  static const title = 'Record when this comes back';

  static const bodyFallback =
      'Next time this repeat comes back, record it. ArchiveMe will compare it with your first proof and show whether it feels stronger, softer, or different.';

  static const label = 'First week loop';

  static const footer =
      'You are not starting again — you are adding evidence.';

  static const recordCta = 'Record when it happens';

  static String bodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” happens, record it. ArchiveMe will compare it with your first repeat and show whether it feels stronger, softer, or different.';
}
