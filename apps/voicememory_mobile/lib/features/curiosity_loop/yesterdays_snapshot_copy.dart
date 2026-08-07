/// Copy for the yesterday snapshot return loop — fast, calm, no advice.
abstract final class YesterdaysSnapshotCopy {
  YesterdaysSnapshotCopy._();

  static const route = '/yesterdays-snapshot';
  static const recordRoute = '/record';

  static const title = "Yesterday's snapshot";
  static const hookEyebrow = 'Carry this forward';
  static const microReviewTitle = 'Yesterday at a glance';
  static const reactionTitle = 'How did it go since then?';
  static const reactionHelper = 'One tap is enough.';

  static const recordingTitle = "Today's moment";
  static const recordingHelper = 'Recording starts automatically.';
  static const recordCta = 'Record today';
  static const typeAnswerCta = 'Type instead';

  static const fallbackBulletOne = 'You saved one voice moment yesterday.';
  static const fallbackBulletTwo = 'ArchiveMe kept the thread for today.';
  static const fallbackBulletThree = 'One quick check-in is enough.';

  static String anchorBullet(String anchor) => 'You were tracking: "$anchor".';
}
