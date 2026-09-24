/// Non-guilt weekly visibility into the pressure loop.
class PressureLoopVisibility {
  const PressureLoopVisibility({
    required this.noticedThisWeek,
    required this.choseToStopCount,
    required this.strongestPhrase,
    required this.streakDays,
  });

  /// Pressure moments noticed in the last 7 days.
  final int noticedThisWeek;

  /// Times the user chose to stop in the last 7 days.
  final int choseToStopCount;

  /// Most frequent pressure option label this week, if any.
  final String? strongestPhrase;

  /// Consecutive days (ending today or yesterday) with at least one check-in.
  final int streakDays;

  bool get hasData => noticedThisWeek > 0 || streakDays > 0;

  static const empty = PressureLoopVisibility(
    noticedThisWeek: 0,
    choseToStopCount: 0,
    strongestPhrase: null,
    streakDays: 0,
  );
}
