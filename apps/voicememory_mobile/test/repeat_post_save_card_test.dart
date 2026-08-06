import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:voicememory_mobile/features/record/daily_mirror_model.dart';
import 'package:voicememory_mobile/features/record/daily_mirror_stage.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/repeat_post_save_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    transcript: transcript,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
    durationSeconds: 30,
    localAudioPath: '/tmp/$id.m4a',
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  group('RepeatPostSaveCard', () {
    const mirror = DailyMirrorResult(
      stage: DailyMirrorStage.possibleLoop,
      heroTitle: 'Loop',
      heroBody:
          'Pressure shows up, then you say yes before checking your capacity.',
      evidenceLine: "In your words: 'said yes' and 'no capacity'.",
      nextQuestion: 'Tomorrow, notice the moment before you agree.',
      primaryCta: 'Record',
      hasGroundedEvidence: true,
      hasChange: false,
      evidenceTerms: ['said yes', 'no capacity'],
      evidenceEntryIds: ['a', 'b'],
    );

    testWidgets('shows calm repeat proof card with one primary CTA', (
      tester,
    ) async {
      var evidenceTapped = false;
      var addMomentTapped = false;
      var doneTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RepeatPostSaveCard(
              entry: _entry(
                id: 'b',
                transcript:
                    'I said yes again even though I had no capacity for one more ask.',
                createdAt: DateTime(2026, 6, 2, 12),
              ),
              allEntries: [
                _entry(
                  id: 'a',
                  transcript:
                      'I had no capacity but I said yes again to the extra meeting today.',
                ),
                _entry(
                  id: 'b',
                  transcript:
                      'I said yes again even though I had no capacity for one more ask.',
                  createdAt: DateTime(2026, 6, 2, 12),
                ),
              ],
              mirror: mirror,
              onViewEvidence: () => evidenceTapped = true,
              onAddOneMoreMoment: () => addMomentTapped = true,
              onDoneForToday: () => doneTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('repeat_post_save_card')), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.repeatPostSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.repeatPostSaveRepeatLabel),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.repeatPostSaveBody),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveFocusedActionsCopy.viewEvidence),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveFocusedActionsCopy.addOneMoreMoment),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSaveDoneForTodayCta),
        findsOneWidget,
      );
      expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
        findsNothing,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.connectToRepeatLabel),
        findsNothing,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel),
        findsNothing,
      );
      expect(find.text(PostSaveFocusedActionsCopy.viewPatterns), findsNothing);

      await tester.tap(find.text(PostSaveFocusedActionsCopy.viewEvidence));
      await tester.pump();
      expect(evidenceTapped, isTrue);

      await tester.tap(find.text(PostSaveFocusedActionsCopy.addOneMoreMoment));
      await tester.pump();
      expect(addMomentTapped, isTrue);

      await tester.tap(
        find.text(VisibleArchiveProofCopy.firstSaveDoneForTodayCta),
      );
      await tester.pump();
      expect(doneTapped, isTrue);
    });

    testWidgets('collapses transcript until expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RepeatPostSaveCard(
              entry: _entry(
                id: 'b',
                transcript: 'I said yes again even though I was tired.',
                createdAt: DateTime(2026, 6, 2, 12),
              ),
              allEntries: [
                _entry(
                  id: 'a',
                  transcript: 'I said yes when I had no capacity.',
                ),
                _entry(
                  id: 'b',
                  transcript: 'I said yes again even though I was tired.',
                  createdAt: DateTime(2026, 6, 2, 12),
                ),
              ],
              mirror: mirror,
              onViewEvidence: () {},
              onAddOneMoreMoment: () {},
              onDoneForToday: () {},
              onCorrectTranscript: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('repeat_post_save_heard_body')),
        findsNothing,
      );
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsNothing);

      await tester.tap(find.byKey(const Key('repeat_post_save_heard_toggle')));
      await tester.pump();

      expect(
        find.byKey(const Key('repeat_post_save_heard_body')),
        findsOneWidget,
      );
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsOneWidget);
    });

    testWidgets('shows thought map only when callback provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RepeatPostSaveCard(
              entry: _entry(id: 'b', transcript: 'Repeat moment.'),
              allEntries: [
                _entry(id: 'a', transcript: 'Earlier moment.'),
                _entry(id: 'b', transcript: 'Repeat moment.'),
              ],
              mirror: mirror,
              onViewEvidence: () {},
              onAddOneMoreMoment: () {},
              onDoneForToday: () {},
              onViewThoughtMap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveFocusedActionsCopy.viewPatterns),
        findsOneWidget,
      );
    });
  });
}
