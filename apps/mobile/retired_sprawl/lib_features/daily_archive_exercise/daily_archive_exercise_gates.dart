/// Visibility gates for daily archive exercise surfaces.
abstract final class DailyArchiveExerciseGates {
  DailyArchiveExerciseGates._();

  static bool showOnArchiveHome({required bool sampleMode}) => !sampleMode;

  static bool showOnRecord({required bool sampleMode}) => !sampleMode;
}