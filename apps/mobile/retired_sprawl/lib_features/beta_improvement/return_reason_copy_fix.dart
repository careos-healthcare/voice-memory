/// Lightweight three-day return plan — optional, no streak.
abstract final class ReturnReasonCopyFix {
  ReturnReasonCopyFix._();

  static const day1 = 'Day 1: Save one real moment.';
  static const day2 = 'Day 2: Save it if something similar happens again.';
  static const day3 =
      'Day 3: ArchiveMe can compare what repeated, changed, or faded.';

  static const optionalFraming = 'Only if it happens again.';
  static const noStreakFraming = 'No streak required.';

  static const postSaveReturnCue = 'Come back if this shows up again.';

  static const threeDayPlan = <String>[day1, day2, day3];

  static Iterable<String> allVisibleStrings() sync* {
    yield day1;
    yield day2;
    yield day3;
    yield optionalFraming;
    yield noStreakFraming;
    yield postSaveReturnCue;
  }
}
