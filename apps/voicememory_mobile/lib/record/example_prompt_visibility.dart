import '../config/app_config.dart';
import '../features/archive_value/archive_value_progress.dart';
import '../models/journal_entry.dart';

/// When to show first-recording conversation starters vs. the continue message.
abstract class ExamplePromptVisibility {
  ExamplePromptVisibility._();

  static const int hideAfterRecordingCount =
      AppConfig.patternReviewReflectionTarget;

  /// True when the user has crossed the first archive growth milestone
  /// (pattern review unlocked at [hideAfterRecordingCount] reflections).
  static bool hasCompletedFirstArchiveMilestone(List<JournalEntry> entries) {
    return ArchiveValueProgress.build(entries).readyForPatternReview;
  }

  static bool shouldShowExamplePrompts({
    required int recordingCount,
    required bool firstArchiveMilestoneCompleted,
  }) {
    if (recordingCount >= hideAfterRecordingCount) return false;
    if (firstArchiveMilestoneCompleted) return false;
    return true;
  }

  static bool shouldShowExamplePromptsForEntries(List<JournalEntry> entries) {
    final count = entries.length;
    final milestone = hasCompletedFirstArchiveMilestone(entries);
    return shouldShowExamplePrompts(
      recordingCount: count,
      firstArchiveMilestoneCompleted: milestone,
    );
  }
}
