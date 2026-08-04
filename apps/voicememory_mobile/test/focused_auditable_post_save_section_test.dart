import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_save_experience_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/save_moment_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';
import 'package:voicememory_mobile/widgets/record/focused_auditable_post_save_section.dart';

void main() {
  testWidgets('first save renders one reduced conclusion after the transcript', (
    tester,
  ) async {
    const transcript =
        'I checked the finished task one more time before sending it.';
    final capturedAt = DateTime(2026, 7, 31, 10);
    final conclusion = ExplainableConclusion(
      id: 'first-observation',
      statement: 'You described checking the finished task one more time.',
      confidence: 60,
      reasoning: const [
        'The saved words describe checking the finished task again.',
      ],
      uncertaintyNote: 'One moment cannot show whether this response repeats.',
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'entry-1',
          quote: transcript,
          startUtf16: 0,
          endUtf16: transcript.length,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: capturedAt,
          sourceType: EvidenceSourceType.text,
        ),
      ],
      alternatives: const [
        ExplainableAlternative(
          statement:
              'This may be specific to this moment rather than something '
              'that repeats.',
          rationale:
              'ArchiveMe has only one supporting moment for this '
              'observation so far.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'test',
        generatedAt: DateTime(2026, 7, 31, 10, 1),
        schemaVersion: ExplainableConclusion.schemaVersion,
      ),
      nextRecordingPrompt:
          'When a task is complete next time, what happens before you send it?',
    );
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: capturedAt,
      transcript: transcript,
      durationSeconds: 20,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: const [],
        exactLanguagePattern: transcript,
        concreteObservation: conclusion.statement,
        repeatedSignal: '',
        explainableConclusion: conclusion,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              FocusedAuditablePostSaveSection(
                experience: const PostSaveExperienceCoordinator().build(
                  SavedMomentResult(
                    entry: entry,
                    entries: [entry],
                    analysisSucceeded: true,
                    syncSucceeded: true,
                  ),
                ),
                onEditTranscript: () {},
                onOpenSavedMoment: () {},
                onRecordNext: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editable transcript'), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_open_saved_moment')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('post_save_supporting_line')), findsOneWidget);
    expect(find.byType(CompactAuditableConclusionCard), findsOneWidget);

    // The transcript always precedes any interpretation.
    expect(
      tester.getTopLeft(find.text('Editable transcript')).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('post_save_compact_conclusion')))
            .dy,
      ),
    );

    expect(find.text('Possible read'), findsOneWidget);
    expect(find.text('“$transcript”'), findsOneWidget);
    expect(find.text('31 July 2026'), findsOneWidget);
    expect(
      find.text('Based on 1 saved moment · Some supporting evidence'),
      findsOneWidget,
    );
    expect(find.text('Accurate'), findsOneWidget);
    expect(find.text('Wrong angle'), findsOneWidget);
    expect(find.text('Too generic'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Check all evidence'), findsOneWidget);

    // One conclusion, one next step, nothing competing with it.
    expect(
      find.byKey(const Key('post_save_compact_conclusion')),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.byKey(const Key('focused_auditable_record_next')),
      findsNothing,
    );
    for (final forbidden in [
      'Pattern proof',
      'Streak',
      'Memory graph',
      'Blind spot',
      'Upgrade',
      'Set a reminder',
      'Alternative explanation',
      'Open exact moment',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('invalid evidence produces the restrained no-conclusion state', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: DateTime(2026, 7, 31),
      transcript: 'A short saved transcript with no supported claim.',
      durationSeconds: 10,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusedAuditablePostSaveSection(
            experience: const PostSaveExperienceCoordinator().build(
              SavedMomentResult(
                entry: entry,
                entries: [entry],
                analysisSucceeded: true,
                syncSucceeded: true,
              ),
            ),
            onEditTranscript: () {},
            onOpenSavedMoment: () {},
            onRecordNext: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('focused_auditable_no_conclusion')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Saved. ArchiveMe does not have enough evidence for a reliable '
        'observation yet.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CompactAuditableConclusionCard), findsNothing);
    expect(
      find.byKey(const Key('focused_auditable_record_next')),
      findsOneWidget,
    );
  });
}
