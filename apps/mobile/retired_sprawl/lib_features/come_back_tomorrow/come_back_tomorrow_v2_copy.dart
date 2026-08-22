/// Copy for Come Back Tomorrow System v2 — no advice, no notifications.
abstract final class ComeBackTomorrowV2Copy {
  ComeBackTomorrowV2Copy._();

  static const postSaveTitle = 'Watch this tomorrow';

  static const postSaveBody =
      'ArchiveMe will look for whether this comes back:';

  static const postSaveFooter =
      'Tomorrow, record if it came back, changed, or stayed quiet.';

  static String quotedPhrase(String phrase) => '“${phrase.trim()}”';

  static const returnQuestionTitle = 'Did this come back?';

  static const returnQuestionBody = 'Last time, ArchiveMe was watching:';

  static const yesCameBack = 'Yes, it came back';
  static const notToday = 'Not today';
  static const different = 'Different this time';

  static const helperCameBack =
      'Record the moment so ArchiveMe can compare it.';
  static const helperNotToday =
      'Okay. That matters too. ArchiveMe will keep watching if it returns.';
  static const helperDifferent =
      'Record what changed so ArchiveMe can compare it.';

  static const cameBackRecordPrompt = 'It came back again today.';
  static const differentRecordPrompt = 'Something felt different this time.';

  static const quietSignalTitle = 'This has not shown up recently';

  static const quietSignalBody =
      'ArchiveMe was watching this thread, but your recent moments did not show it.';

  static const quietSignalFooter = 'That may matter too.';

  static const quietSignalCta = 'Keep watching';

  static const List<String> all = [
    postSaveTitle,
    postSaveBody,
    postSaveFooter,
    returnQuestionTitle,
    returnQuestionBody,
    yesCameBack,
    notToday,
    different,
    helperCameBack,
    helperNotToday,
    helperDifferent,
    quietSignalTitle,
    quietSignalBody,
    quietSignalFooter,
    quietSignalCta,
  ];
}