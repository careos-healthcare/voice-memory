/// Visibility gates for today's one question surfaces.
abstract final class TodaysQuestionGates {
  TodaysQuestionGates._();

  static bool showOnRecord({required bool sampleMode}) => !sampleMode;
}