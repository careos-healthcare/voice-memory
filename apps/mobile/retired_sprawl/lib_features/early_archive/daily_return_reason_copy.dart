/// Copy for the daily return reason card — one reason to record today.
abstract final class DailyReturnReasonCopy {
  DailyReturnReasonCopy._();

  static const title = "Today's reason to record";

  static const missingTriggerBody =
      'ArchiveMe is still missing what happens before this repeat.';
  static const missingTriggerPrompt =
      'Record what happened right before it appeared.';

  static const missingThoughtBody =
      'ArchiveMe is still missing what your mind says in the moment.';
  static const missingThoughtPrompt =
      'Record the thought that shows up with it.';

  static const missingActionBody =
      'ArchiveMe is still missing what you do next.';
  static const missingActionPrompt = 'Record what you did when it appeared.';

  static const missingResultBody =
      'ArchiveMe is still missing whether it helped, cost you, or changed.';
  static const missingResultPrompt = 'Record what happened after it.';

  static const missingChangeBody =
      'ArchiveMe knows the repeat. Now it needs the next return to see whether it changes.';
  static const missingChangePrompt = 'Record the next time it happens.';

  static const missingPositiveBody =
      'ArchiveMe is also watching for what helps.';
  static const missingPositivePrompt = 'Record one thing that helped today.';

  static const completeBody =
      'ArchiveMe has a strong picture. The next useful moment is any time this pattern returns.';
  static const completePrompt = 'Record the next real moment.';

  static const recordCta = 'Record this';

  static const missingChangeGuided = 'What happened when this came up again?';
  static const missingPositiveGuided = 'What helped in this moment?';
}