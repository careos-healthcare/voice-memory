/// Lightweight first-week challenge tracker — local journal evidence only.
enum ThreeDayChallengeDay {
  day1,
  day2,
  day3,
  complete,
}

class ThreeDayChallengeState {
  const ThreeDayChallengeState({
    required this.day,
    required this.title,
    required this.body,
    required this.entryCount,
    required this.distinctDayCount,
    required this.isComplete,
  });

  final ThreeDayChallengeDay day;
  final String title;
  final String body;
  final int entryCount;
  final int distinctDayCount;
  final bool isComplete;
}
