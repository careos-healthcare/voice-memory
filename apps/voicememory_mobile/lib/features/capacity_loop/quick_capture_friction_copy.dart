import 'quick_capture_friction_models.dart';

/// Copy for quick capture friction check — workload proof only.
abstract final class QuickCaptureFrictionCopy {
  QuickCaptureFrictionCopy._();

  static const title = 'Was this easy enough?';
  static const body =
      'You saved a yes moment without explaining everything. Did this feel light enough to use again?';

  static const saveAnswerCta = 'Save answer';
  static const skipCta = 'Skip for now';

  static const dashboardLabel = 'Quick capture friction';
  static const dashboardNotAnswered = 'not answered';
  static const dashboardQuickEnough = 'quick enough';
  static const dashboardMostly = 'mostly';
  static const dashboardStillWork = 'still work';
  static const dashboardNotSure = 'not sure';
  static const dashboardSkipped = 'skipped';

  static String labelForResponse(String id) => switch (id) {
    QuickCaptureFrictionResponseIds.quickEnough => 'Yes — quick enough',
    QuickCaptureFrictionResponseIds.mostly => 'Mostly',
    QuickCaptureFrictionResponseIds.stillWork => 'Still felt like work',
    QuickCaptureFrictionResponseIds.notSure => 'Not sure yet',
    _ => '',
  };

  static String dashboardValueForRecord(QuickCaptureFrictionRecord? record) {
    if (record == null || !record.isComplete) {
      return dashboardNotAnswered;
    }
    if (record.isSkipped) return dashboardSkipped;
    return switch (record.responseId) {
      QuickCaptureFrictionResponseIds.quickEnough => dashboardQuickEnough,
      QuickCaptureFrictionResponseIds.mostly => dashboardMostly,
      QuickCaptureFrictionResponseIds.stillWork => dashboardStillWork,
      QuickCaptureFrictionResponseIds.notSure => dashboardNotSure,
      _ => dashboardNotAnswered,
    };
  }

  static String dashboardLineForRecord(QuickCaptureFrictionRecord? record) =>
      '$dashboardLabel: ${dashboardValueForRecord(record)}';

  static List<String> allVisibleStrings() => [
    title,
    body,
    saveAnswerCta,
    skipCta,
    dashboardLabel,
    dashboardNotAnswered,
    dashboardQuickEnough,
    dashboardMostly,
    dashboardStillWork,
    dashboardNotSure,
    dashboardSkipped,
    ...QuickCaptureFrictionResponseIds.all.map(labelForResponse),
  ];
}
