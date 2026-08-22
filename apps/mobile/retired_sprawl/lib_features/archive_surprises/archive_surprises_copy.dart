import 'package:archiveme_mobile/design/user_facing_date.dart';

/// User-facing Archive Surprises strings.
abstract class ArchiveSurprisesCopy {
  ArchiveSurprisesCopy._();

  static const String sectionTitle = 'Surprises';

  static const String emptyNeedMoreEvidence =
      'Surprises appear after you have enough reflections with usable transcripts.';

  static const String emptyNoneYet =
      'No evidence-backed surprises yet — the archive needs a clearer pattern across time.';

  static const String evidenceLabel = 'Evidence';

  static String themeDominanceGap({
    required String dominantLabel,
    required int dominantPercent,
    required String contrastLabel,
    required int contrastPercent,
    required int contrastCount,
  }) =>
      'You mention $dominantLabel $dominantPercent% of the time but rarely mention '
      '$contrastLabel ($contrastPercent%, $contrastCount '
      '${contrastCount == 1 ? 'recording' : 'recordings'}).';

  static String themeStoppedMentioning({
    required String themeLabel,
    required DateTime lastMentionMonth,
  }) =>
      'You stopped mentioning $themeLabel concerns in '
      '${formatUserFacingMonthYear(lastMentionMonth)}.';

  static String repeatedDecisionLoop({
    required int weekCount,
    required int recordingCount,
  }) =>
      'You revisit the same decision across $weekCount weeks '
      '($recordingCount ${recordingCount == 1 ? 'recording' : 'recordings'}).';

  static String statedImportanceGap({
    required String themeLabel,
    required int sharePercent,
    required int mentionCount,
  }) =>
      'You describe $themeLabel as important, but only $sharePercent% of your '
      'eligible recordings mention it ($mentionCount '
      '${mentionCount == 1 ? 'mention' : 'mentions'}).';
}