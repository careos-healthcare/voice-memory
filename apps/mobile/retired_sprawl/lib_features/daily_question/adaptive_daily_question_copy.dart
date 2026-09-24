/// Adaptive copy for today's one question on Record.
abstract final class AdaptiveDailyQuestionCopy {
  AdaptiveDailyQuestionCopy._();

  static const noEntriesQuestion = 'What is one real moment from today?';
  static const noEntriesHelper = 'Short is fine. Ten seconds is enough.';

  static const oneEntryQuestion = 'Did anything similar happen again?';
  static const oneEntryHelper = 'ArchiveMe needs a second moment to compare.';

  static const twoNoClearMatchQuestion =
      'What felt similar or different from your last two moments?';
  static const twoNoClearMatchHelper = 'No need to force a pattern.';

  static const twoRelatedQuestion = 'Can you record one more related moment?';
  static const twoRelatedHelper =
      'One more related moment unlocks first proof.';

  static const confirmedRepeatQuestionFallback =
      'Did this repeat come back today?';
  static const confirmedRepeatHelper = 'ArchiveMe can compare what changed.';

  static const returnSofterQuestion =
      'Did this feel softer again, or different this time?';
  static const returnSofterHelper =
      'ArchiveMe is watching whether the shift holds.';

  static const returnStrongerQuestion =
      'Did this feel stronger again, or different this time?';
  static const returnStrongerHelper = 'ArchiveMe is watching what changes.';

  static const returnSameQuestion = 'Did this feel about the same again?';
  static const returnSameHelper = 'ArchiveMe compares returns over time.';

  static const patternChangedQuestion =
      'Did the change hold when this came back?';
  static const patternChangedHelper =
      'ArchiveMe is watching whether this shift holds.';

  static const helpfulActionQuestionFallback =
      'Did a helpful action appear again?';
  static const helpfulActionHelper = 'This is evidence, not advice.';

  static String confirmedRepeatQuestion(String phrase) =>
      'Did “$phrase” come back today?';

  static String helpfulActionQuestion(String action) =>
      'Did “$action” appear again?';

  static List<String> get allVisibleStrings => [
    noEntriesQuestion,
    noEntriesHelper,
    oneEntryQuestion,
    oneEntryHelper,
    twoNoClearMatchQuestion,
    twoNoClearMatchHelper,
    twoRelatedQuestion,
    twoRelatedHelper,
    confirmedRepeatQuestionFallback,
    confirmedRepeatHelper,
    returnSofterQuestion,
    returnSofterHelper,
    returnStrongerQuestion,
    returnStrongerHelper,
    returnSameQuestion,
    returnSameHelper,
    patternChangedQuestion,
    patternChangedHelper,
    helpfulActionQuestionFallback,
    helpfulActionHelper,
  ];
}
