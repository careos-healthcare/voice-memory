/// Visibility gates for user-confirmed insight feedback.
abstract final class InsightFeedbackGates {
  InsightFeedbackGates._();

  static bool showForThenVsNow({required bool hasInsight}) => hasInsight;

  static bool showForArchiveClarity({required bool hasInsight}) => hasInsight;
}