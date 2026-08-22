import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';

/// Copy for Return Day Flow v2 — next-day return on record ready.
abstract final class ReturnDayFlowCopy {
  ReturnDayFlowCopy._();

  static const String title = ComeBackTomorrowV2Copy.returnQuestionTitle;

  static const String defaultBody = ComeBackTomorrowV2Copy.returnQuestionBody;

  static String bodyWithPhrase(String phrase) => defaultBody;

  static const String yesCameBack = ComeBackTomorrowV2Copy.yesCameBack;
  static const String notToday = ComeBackTomorrowV2Copy.notToday;
  static const String different = ComeBackTomorrowV2Copy.different;

  static const String helperCameBack = ComeBackTomorrowV2Copy.helperCameBack;
  static const String helperNotToday = ComeBackTomorrowV2Copy.helperNotToday;
  static const String helperDifferent = ComeBackTomorrowV2Copy.helperDifferent;

  static const String cameBackRecordPrompt =
      ComeBackTomorrowV2Copy.cameBackRecordPrompt;
  static const String differentRecordPrompt =
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