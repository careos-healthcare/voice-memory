/// Local reminder copy. No streak counters and no pressure to record.
abstract final class GentleRemindersCopy {
  GentleRemindersCopy._();

  static const optInTitle = 'Reminders, only if you want them';
  static const optInBody =
      'A time you choose, an old entry in your own words, or a look back you already asked for. Skip any day.';
  static const turnOn = 'Turn on reminders';
  static const notNow = 'Not now';

  static const settingsDaily = 'Daily nudge';
  static const settingsOnThisDay = 'On this day';
  static const settingsCheckBack = 'Check back';
  static const settingsWeeklyRecap = 'Weekly recap';
  static const settingsQuietHours = 'Quiet hours';

  static const dailyNotificationTitle = 'If you want to record';
  static const dailyNotificationBody = 'There is no need to record today.';
  static const onThisDayNotificationTitle = 'From your archive';
  static const checkBackNotificationTitle = 'You asked to look at this again';
  static const weeklyRecapNotificationTitle = 'Your week in your own words';
  static const weeklyRecapNotificationBody =
      'Your week in your own words is ready.';
}
