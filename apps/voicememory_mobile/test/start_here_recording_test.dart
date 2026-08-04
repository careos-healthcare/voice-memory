import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/record/start_here_catalog.dart';
import 'package:voicememory_mobile/record/start_here_visibility.dart';
import 'package:voicememory_mobile/widgets/record/start_here_recording_section.dart';

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
  group('StartHereCatalog', () {
    test('includes four Start Here options', () {
      expect(StartHereCatalog.sectionTitle, 'Try saying one of these');
      expect(StartHereCatalog.prompts, hasLength(4));
      expect(StartHereCatalog.prompts.first, 'What happened today?');
      expect(
        StartHereCatalog.continueBuildingArchive,
        'Keep adding moments to sharpen what repeats.',
      );
    });
  });

  group('StartHereVisibility', () {
    test('shows Start Here below milestone threshold', () {
      expect(
        StartHereVisibility.shouldShowStartHere(
          recordingCount: 2,
          firstArchiveMilestoneCompleted: false,
        ),
        isTrue,
      );
    });

    test('hides Start Here at pattern review threshold', () {
      expect(
        StartHereVisibility.shouldShowStartHere(
          recordingCount: AppConfig.patternReviewReflectionTarget,
          firstArchiveMilestoneCompleted: false,
        ),
        isFalse,
      );
    });

    test('hides Start Here when first archive milestone completed', () {
      final entries = List.generate(
        AppConfig.patternReviewReflectionTarget,
        (i) => _entry('e$i'),
      );
      expect(
        StartHereVisibility.shouldShowStartHereForEntries(entries),
        isFalse,
      );
    });
  });

  group('StartHereRecordingSection', () {
    testWidgets('renders Start Here title and all options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartHereRecordingSection(
              recordingCount: 0,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('start_here_section')), findsOneWidget);
      expect(find.text('Try saying one of these'), findsOneWidget);
      for (final prompt in StartHereCatalog.prompts) {
        expect(find.text(prompt), findsOneWidget);
      }
      expect(find.text(StartHereCatalog.continueBuildingArchive), findsNothing);
    });

    testWidgets('tap invokes callback with prompt', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartHereRecordingSection(
              recordingCount: 1,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (p) => tapped = p,
              surface: 'test',
              captureMode: 'text',
            ),
          ),
        ),
      );

      await tester.tap(find.text("What's bothering you?"));
      await tester.pump();
      expect(tapped, "What's bothering you?");
    });

    testWidgets('shows continue message after milestone threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartHereRecordingSection(
              recordingCount: 5,
              firstArchiveMilestoneCompleted: false,
              onPromptSelected: (_) {},
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text('Try saying one of these'), findsNothing);
      expect(
        find.byKey(const Key('start_here_continue_message')),
        findsOneWidget,
      );
      expect(
        find.text(StartHereCatalog.continueBuildingArchive),
        findsOneWidget,
      );
    });
  });
}
