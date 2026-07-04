/// Copy for Return Day Flow v2 — next-day return on record ready.
abstract final class ReturnDayFlowCopy {
  ReturnDayFlowCopy._();

  static const title = 'Did it show up again?';

  static const defaultBody = 'Record what happened if it came back.';

  static String bodyWithPhrase(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return defaultBody;
    return 'ArchiveMe was watching: “$trimmed”';
  }

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
    title,
    defaultBody,
    yesCameBack,
    notToday,
    different,
    helperCameBack,
    helperNotToday,
    helperDifferent,
  ];
}
