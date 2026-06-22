import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/correction_informed_next_prompt.dart';
import 'package:voicememory_mobile/features/activation/next_moment_prompt.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/next_moment_prompt_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _entries(int count) => List.generate(
      count,
      (i) => _voiceEntry(
        id: 'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired moment $i.',
        createdAt: DateTime(2026, 6, 9 + i, 12),
      ),
    );

const _privateNote = 'This is not about work - it is more about family.';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('CorrectionInformedNextPrompt', () {
    test('no correction note keeps existing next-moment prompt unchanged', () {
      final prompt = NextMomentPromptEngine.build(entries: _entries(4));
      expect(prompt!.title, VisibleArchiveProofCopy.nextMomentFourTitle);
      expect(prompt.body, VisibleArchiveProofCopy.nextMomentFourBody);
    });

    test('correction note on belief target shows retest prompt at 4+ entries', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        _privateNote,
      );

      final prompt = NextMomentPromptEngine.build(entries: _entries(4))!;
      expect(prompt.title, VisibleArchiveProofCopy.correctionNextFourTitle);
      expect(prompt.body, VisibleArchiveProofCopy.correctionNextFourBody);
      expect(prompt.secondaryCta, 'View evidence');
      expect(prompt.secondaryAction, NextMomentPromptAction.viewEvidence);
      expect(prompt.body.toLowerCase(), isNot(contains(_privateNote.toLowerCase())));
      _expectNoBannedCopy([prompt.title, prompt.body]);
    });

    test('correction note on weekly review target shows review prompt at 5+', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
        _privateNote,
      );

      final prompt = NextMomentPromptEngine.build(entries: _entries(5))!;
      expect(prompt.title, VisibleArchiveProofCopy.correctionNextFiveReviewTitle);
      expect(prompt.body, VisibleArchiveProofCopy.correctionNextFiveReviewBody);
      expect(prompt.secondaryCta, 'View review');
      expect(prompt.secondaryAction, NextMomentPromptAction.viewReview);
      expect(prompt.body.toLowerCase(), isNot(contains(_privateNote.toLowerCase())));
    });

    test('correction note on archive home at 3 entries uses generic prompt with thin evidence',
        () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.archiveHomeId(ArchiveHomeStage.three),
        _privateNote,
      );

      final prompt = NextMomentPromptEngine.build(entries: _entries(3))!;
      expect(prompt.title, VisibleArchiveProofCopy.correctionNextGenericTitle);
      expect(prompt.body, contains('not quite right'));
      expect(prompt.body, contains('still thin'));
      expect(prompt.secondaryCta, isNull);
    });

    test('correction note is not treated as fact or certainty in prompt copy', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        _privateNote,
      );
      final prompt = NextMomentPromptEngine.build(entries: _entries(4))!;
      expect(prompt.body.toLowerCase(), contains('your note says'));
      expect(prompt.body.toLowerCase(), isNot(contains('this is true')));
      expect(prompt.body.toLowerCase(), isNot(contains('you always')));
      expect(prompt.title.toLowerCase(), isNot(contains('confirmed')));
    });

    test('empty or whitespace correction note is ignored', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        '   ',
      );
      final prompt = NextMomentPromptEngine.build(entries: _entries(4));
      expect(prompt!.title, VisibleArchiveProofCopy.nextMomentFourTitle);
    });

    test('hidden target does not drive correction-aware prompt', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
        _privateNote,
      );
      ArchiveInsightFeedbackStore.hide(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
      );

      final prompt = NextMomentPromptEngine.build(entries: _entries(5));
      expect(prompt!.title, VisibleArchiveProofCopy.nextMomentFivePlusTitle);
    });

    test('degraded entries do not count toward correction prompt ladder', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.archiveHomeId(ArchiveHomeStage.three),
        _privateNote,
      );
      final prompt = NextMomentPromptEngine.build(
        entries: [
          ..._entries(2),
          _degradedVoiceEntry(id: 'e3'),
        ],
      );
      expect(prompt!.stage, NextMomentPromptStage.two);
      expect(prompt.title, VisibleArchiveProofCopy.nextMomentTwoTitle);
    });

    test('activeContext prefers weekly review over belief when both have notes', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        'Belief note',
      );
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
        _privateNote,
      );

      final context = CorrectionInformedNextPrompt.activeContext(eligibleCount: 5);
      expect(context?.target, CorrectionInformedPromptTarget.weeklyReview);
    });
  });

  group('Archive Home next action integration', () {
    test('uses correction-aware next action title when note exists', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.archiveHomeId(ArchiveHomeStage.four),
        _privateNote,
      );
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        _privateNote,
      );

      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      expect(summary.nextActionLine, VisibleArchiveProofCopy.correctionNextFourTitle);
    });
  });

  group('Correction note privacy in prompts', () {
    test('shareable archive proof does not include correction note or prompt note text',
        () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
        _privateNote,
      );
      final prompt = NextMomentPromptEngine.build(entries: _entries(5))!;
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      final shareText = proof.lines.join('\n');
      expect(shareText.toLowerCase(), isNot(contains(_privateNote.toLowerCase())));
      expect(shareText.toLowerCase(), isNot(contains(prompt.title.toLowerCase())));
    });
  });

  group('NextMomentPromptCard correction routes', () {
    testWidgets('View evidence and View review callbacks still work', (tester) async {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        _privateNote,
      );
      var primaryTapped = false;
      var secondaryTapped = false;
      final prompt = NextMomentPromptEngine.build(entries: _entries(4))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: NextMomentPromptCard(
              prompt: prompt,
              onPrimary: () => primaryTapped = true,
              onSecondary: () => secondaryTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('next_moment_prompt_primary_cta')));
      await tester.pump();
      expect(primaryTapped, isTrue);

      await tester.tap(find.byKey(const Key('next_moment_prompt_secondary_cta')));
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });
  });
}
