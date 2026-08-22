/// First-week progress states in the early return loop.
enum FirstWeekProgressState { day1, day2, firstProof, day3to7 }

/// Lightweight first-week progress — title/body only, no CTAs.
class FirstWeekProgress {
  const FirstWeekProgress({
    required this.state,
    required this.title,
    required this.body,
    required this.weekDay,
  });

  final FirstWeekProgressState state;
  final String title;
  final String body;

  /// Calendar day number within the first week (1–7).
  final int weekDay;
}