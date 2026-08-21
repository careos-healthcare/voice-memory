import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/record/example_prompt_visibility.dart';

/// When to show Start Here vs. the continue-building message.
abstract class StartHereVisibility {
  StartHereVisibility._();

  static bool hasCompletedFirstArchiveMilestone(List<JournalEntry> entries) =>
      ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(entries);

  static bool shouldShowStartHere({
    required int recordingCount,
    required bool firstArchiveMilestoneCompleted,
  }) => ExamplePromptVisibility.shouldShowExamplePrompts(
    recordingCount: recordingCount,
    firstArchiveMilestoneCompleted: firstArchiveMilestoneCompleted,
  );

  static bool shouldShowStartHereForEntries(List<JournalEntry> entries) =>
      ExamplePromptVisibility.shouldShowExamplePromptsForEntries(entries);
}