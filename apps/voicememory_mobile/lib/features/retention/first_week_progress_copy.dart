/// Copy for the first-week progress line — no streaks, no shame.
abstract final class FirstWeekProgressCopy {
  FirstWeekProgressCopy._();

  static const day1Title = 'Day 1 of 7';
  static const day1Body = 'ArchiveMe starts with one real moment.';

  static const day2Title = 'Day 2 of 7';
  static const day2Body = 'Come back when the same thing shows up again.';

  static const firstProofTitle = 'First proof reached';
  static const firstProofBody = 'ArchiveMe can now compare what changes.';

  static String dayNTitle(int day) => 'Day $day of 7';
  static const day3to7Body =
      'ArchiveMe gets sharper when you return to the same pattern.';

  static const List<String> all = [
    day1Title,
    day1Body,
    day2Title,
    day2Body,
    firstProofTitle,
    firstProofBody,
    day3to7Body,
  ];
}
