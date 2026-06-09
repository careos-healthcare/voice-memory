import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/example_prompt_catalog.dart';
import 'package:voicememory_mobile/record/example_prompt_visibility.dart';

JournalEntry _entry(String id) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    transcript:
        'Enough transcript length for archive evidence and pattern review.',
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work showed up again in this reflection today.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  group('ExamplePromptVisibility', () {
    test('shows prompts below recording threshold without milestone', () {
      expect(
        ExamplePromptVisibility.shouldShowExamplePrompts(
          recordingCount: 2,
          firstArchiveMilestoneCompleted: false,
        ),
        isTrue,
      );
    });

    test('hides prompts at 5+ recordings', () {
      expect(
        ExamplePromptVisibility.shouldShowExamplePrompts(
          recordingCount: AppConfig.patternReviewReflectionTarget,
          firstArchiveMilestoneCompleted: false,
        ),
        isFalse,
      );
    });

    test('hides prompts when first archive milestone completed', () {
      final entries = List.generate(
        AppConfig.patternReviewReflectionTarget,
        (i) => _entry('e$i'),
      );
      expect(
        ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(entries),
        isTrue,
      );
      expect(
        ExamplePromptVisibility.shouldShowExamplePromptsForEntries(entries),
        isFalse,
      );
    });
  });

  group('ExamplePromptCatalog', () {
    test('includes four conversation starters', () {
      expect(ExamplePromptCatalog.prompts, hasLength(4));
      expect(ExamplePromptCatalog.sectionTitle, 'Need an idea?');
      expect(
        ExamplePromptCatalog.continueBuildingArchive,
        ConsumerUiCopy.continueBuildingPatterns,
      );
    });
  });
}
