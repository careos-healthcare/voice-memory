import '../come_back_tomorrow/come_back_tomorrow_v2_copy.dart';

/// Copy for Return Day Flow v2 — next-day return on record ready.
abstract final class ReturnDayFlowCopy {
  ReturnDayFlowCopy._();

  static const title = ComeBackTomorrowV2Copy.returnQuestionTitle;

  static const defaultBody = ComeBackTomorrowV2Copy.returnQuestionBody;

  static String bodyWithPhrase(String phrase) => defaultBody;

  static const yesCameBack = ComeBackTomorrowV2Copy.yesCameBack;
  static const notToday = ComeBackTomorrowV2Copy.notToday;
  static const different = ComeBackTomorrowV2Copy.different;

  static const helperCameBack = ComeBackTomorrowV2Copy.helperCameBack;
  static const helperNotToday = ComeBackTomorrowV2Copy.helperNotToday;
  static const helperDifferent = ComeBackTomorrowV2Copy.helperDifferent;

  static const cameBackRecordPrompt = ComeBackTomorrowV2Copy.cameBackRecordPrompt;
  static const differentRecordPrompt =
      ComeBackTomorrowV2Copy.differentRecordPrompt;

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
