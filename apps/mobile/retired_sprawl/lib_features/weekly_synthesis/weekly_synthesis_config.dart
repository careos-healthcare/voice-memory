/// WorkManager + SQLite constants for weekly topic synthesis.
abstract final class WeeklySynthesisConfig {
  WeeklySynthesisConfig._();

  static const taskUniqueName = 'com.voicememory.mobile.weeklyTopicSynthesis';
  static const taskName = 'weeklyTopicSynthesis';

  /// Same identifier registered in iOS Info.plist + AppDelegate.
  static const iosProcessingTaskId = taskUniqueName;

  static const lookbackDays = 7;
  static const minTopicMentions = 2;
  static const maxTopicClusters = 24;

  static const synthesisNodeKind = 'weekly_synthesis';
  static const synthesisEntryIdPrefix = 'weekly-synthesis';

  /// iOS BGProcessing / Android WorkManager soft time budget for Gemma inference.
  static const inferenceTimeBudget = Duration(seconds: 25);
}
