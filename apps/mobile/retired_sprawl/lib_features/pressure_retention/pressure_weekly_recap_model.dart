/// Lightweight recap of the last 7 days of pressure check-ins.
class PressureWeeklyRecap {
  const PressureWeeklyRecap({
    required this.count,
    required this.mostCommonOptionLabel,
    required this.mostCommonContextLabel,
    required this.choseToStopCount,
    required this.sentence,
  });

  final int count;
  final String? mostCommonOptionLabel;
  final String? mostCommonContextLabel;
  final int choseToStopCount;

  /// One evidence-based sentence that never overclaims on weak data.
  final String sentence;

  bool get hasData => count > 0;
}