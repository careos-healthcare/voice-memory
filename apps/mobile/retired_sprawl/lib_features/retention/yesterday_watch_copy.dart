/// Copy for the yesterday-watch return loop — no advice, no notifications.
abstract final class YesterdayWatchCopy {
  YesterdayWatchCopy._();

  static const defaultTitle = 'Yesterday, ArchiveMe was watching this';
  static const defaultBody = 'Record what happened if it showed up again.';

  static String titleWithPhrase(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return defaultTitle;
    return 'Yesterday, ArchiveMe was watching: “$trimmed”';
  }

  static const phraseBody = 'Did it show up again?';

  static const yesCameBack = 'Yes, it came back';
  static const notToday = 'Not today';
  static const different = 'Different this time';

  static const helperCameBack =
      'Record the moment so ArchiveMe can compare it.';
  static const helperNotToday =
      'Okay. ArchiveMe will keep watching when it returns.';
  static const helperDifferent = 'Record what felt different.';

  static const cameBackRecordPrompt = 'It came back again today.';
  static const differentRecordPrompt = 'Something felt different this time.';

  static const List<String> all = [
    defaultTitle,
    defaultBody,
    phraseBody,
    yesCameBack,
    notToday,
    different,
    helperCameBack,
    helperNotToday,
    helperDifferent,
  ];
}
