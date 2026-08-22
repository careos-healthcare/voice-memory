/// Copy for the pattern-changed payoff — grounded evidence only.
abstract final class PatternChangedCopy {
  PatternChangedCopy._();

  static const title = 'Something changed this time';

  static const earlierLabel = 'Earlier';

  static const thisTimeLabel = 'This time';

  static const bodyFallback =
      'This return still connects to your first proof, but something around it '
      'looked different this time.';

  static const footer =
      'ArchiveMe will keep watching whether this shift holds.';

  static String bodyWithPhrases(String oldPhrase, String newPhrase) =>
      'Earlier, this showed up as "$oldPhrase". This time, ArchiveMe noticed '
      '"$newPhrase".';

  static const recordIfReturnsCta = 'Record when it returns';

  static const dismiss = 'Dismiss';
}