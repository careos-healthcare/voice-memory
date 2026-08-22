import 'package:archiveme_mobile/features/current_relevance/current_relevance_model.dart';

/// Copy for the current relevance bridge — correction layer, not proof.
abstract final class CurrentRelevanceCopy {
  CurrentRelevanceCopy._();

  static const title = 'Does this still affect today?';

  static const body =
      'ArchiveMe found something that appeared before. '
      'That does not mean it matters equally now.';

  static const differentiationLine =
      'ChatGPT can respond to one conversation. '
      'ArchiveMe compares saved moments and lets you correct what still matters.';

  static const List<String> all = [
    title,
    body,
    differentiationLine,
    optionYes,
    optionLittle,
    optionNotReally,
    optionNotSure,
    responseYes,
    responseLittle,
    responseNotReally,
    responseNotSure,
  ];

  static const optionYes = 'Yes, this still affects me';
  static const optionLittle = 'A little';
  static const optionNotReally = 'Not really anymore';
  static const optionNotSure = "I'm not sure";

  static String optionLabel(CurrentRelevanceAnswer answer) => switch (answer) {
    CurrentRelevanceAnswer.yes => optionYes,
    CurrentRelevanceAnswer.little => optionLittle,
    CurrentRelevanceAnswer.notReally => optionNotReally,
    CurrentRelevanceAnswer.notSure => optionNotSure,
  };

  static const responseYes =
      'This looks current. ArchiveMe will keep watching how it shows up now.';
  static const responseLittle =
      'This may still matter, but not equally every time. '
      'ArchiveMe will treat it as a soft signal.';
  static const responseNotReally =
      'Good to know. ArchiveMe will not treat this as urgent '
      'just because it appeared before.';
  static const responseNotSure =
      'ArchiveMe will keep this lightly in view and wait for stronger evidence.';

  static String responseFor(CurrentRelevanceAnswer answer) => switch (answer) {
    CurrentRelevanceAnswer.yes => responseYes,
    CurrentRelevanceAnswer.little => responseLittle,
    CurrentRelevanceAnswer.notReally => responseNotReally,
    CurrentRelevanceAnswer.notSure => responseNotSure,
  };
}