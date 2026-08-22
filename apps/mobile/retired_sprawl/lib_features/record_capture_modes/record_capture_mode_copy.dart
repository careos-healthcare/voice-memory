/// User-facing copy for open capture modes on Record.
abstract final class RecordCaptureModeCopy {
  RecordCaptureModeCopy._();

  static const String cardTitle = 'Start with anything real';
  static const String cardSubtitle = 'It does not have to be a big moment.';

  static const String somethingHappenedLabel = 'Something that happened';
  static const String somethingHappenedHelper =
      'A normal moment from today is enough.';
  static const String somethingHappenedPrompt = 'What happened?';

  static const String keptThinkingLabel = 'Something I kept thinking about';
  static const String keptThinkingHelper =
      'Record the thought, even if it feels unfinished.';
  static const String keptThinkingPrompt = 'What kept coming back to mind?';

  static const String smallWinLabel = 'A small win';
  static const String smallWinHelper = 'ArchiveMe can track what helps too.';
  static const String smallWinPrompt = 'What went a little better?';

  static const String pressureMomentLabel = 'A pressure moment';
  static const String pressureMomentHelper =
      'Use this when something felt urgent, heavy, or hard to say no to.';
  static const String pressureMomentPrompt = 'What was the pressure moment?';

  static const String nothingMuchTodayLabel = 'Nothing much today';
  static const String nothingMuchTodayHelper =
      'That still counts. You can simply mark today as quiet.';
  static const String nothingMuchTodayPrompt =
      'Was there anything small worth noting?';

  static const String quietDayDefaultSaveText = 'Nothing much today.';
  static const String quietDaySaveButton = 'Save as quiet day';

  static const String noPatternReassurance =
      'Saved. ArchiveMe does not need every entry to become a pattern.';
  static const String quietDaySaved = 'Saved as a quiet day.';
  static const String quietDayWatching =
      'ArchiveMe will keep watching when something stands out.';
}