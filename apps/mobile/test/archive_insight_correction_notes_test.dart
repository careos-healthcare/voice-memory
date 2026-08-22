import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback_adaptation.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_home_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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

List<JournalEntry> _entries(int count) => List.generate(
  count,
  (i) => _voiceEntry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    createdAt: DateTime(2026, 6, 9 + i, 12),
  ),
);

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

const _privateNote = 'This is not about work - it is more about family.';

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

Future<void> _pumpArchiveHomeCard(WidgetTester tester) async {
  final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArchiveHomeSummaryCard(summary: summary, onPrimary: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async => ArchiveInsightFeedbackStore.resetForTest());

  group('ArchiveInsightFeedbackStore correction notes', () {
    test('empty correction note is not saved', () async {
      const id = 'archive_home_three';
      expect(
        await ArchiveInsightFeedbackStore.saveCorrectionNote(id, '   '),
        isFalse,
      );
      expect(ArchiveInsightFeedbackStore.hasCorrectionNote(id), isFalse);
    });

    test('valid correction note is stored locally for that target', () async {
      const id = 'archive_home_three';
      expect(
        await ArchiveInsightFeedbackStore.saveCorrectionNote(id, _privateNote),
        isTrue,
      );
      expect(ArchiveInsightFeedbackStore.correctionNote(id), _privateNote);
      expect(ArchiveInsightFeedbackStore.hasCorrectionNote(id), isTrue);
    });

    test('correction note does not affect unrelated targets', () async {
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'archive_home_three',
        _privateNote,
      );
      expect(
        ArchiveInsightFeedbackStore.hasCorrectionNote('weeklyReview'),
        isFalse,
      );
    });

    test('correction note is capped safely at 240 characters', () async {
      const id = 'weeklyReview';
      final longNote = 'a' * 300;
      expect(
        await ArchiveInsightFeedbackStore.saveCorrectionNote(id, longNote),
        isTrue,
      );
      expect(
        ArchiveInsightFeedbackStore.correctionNote(id)!.length,
        ArchiveInsightFeedbackStore.maxCorrectionNoteLength,
      );
    });

    test('correction note can be replaced with latest note only', () async {
      const id = 'beliefUpdate';
      await ArchiveInsightFeedbackStore.saveCorrectionNote(id, 'First note');
      await ArchiveInsightFeedbackStore.saveCorrectionNote(id, 'Updated note');
      expect(ArchiveInsightFeedbackStore.correctionNote(id), 'Updated note');
    });
  });

  group('ArchiveInsightFeedbackControls correction UI', () {
    testWidgets('tapping Not quite reveals correction note affordance', (
      tester,
    ) async {
      await _pumpArchiveHomeCard(tester);
      expect(
        find.byKey(const Key('archive_insight_feedback_correction_affordance')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_not_quite')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_insight_feedback_correction_affordance')),
        findsOneWidget,
      );
      expect(find.text('Tell ArchiveMe what it missed'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_insight_feedback_correction_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_correction_save')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_correction_skip')),
        findsOneWidget,
      );
    });

    testWidgets('empty correction note is not saved from editor', (
      tester,
    ) async {
      await _pumpArchiveHomeCard(tester);
      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_not_quite')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('archive_insight_feedback_correction_field')),
        '   ',
      );
      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_correction_save')),
      );
      await tester.pump();

      expect(
        ArchiveInsightFeedbackStore.hasCorrectionNote('archive_home_three'),
        isFalse,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_correction_saved_note')),
        findsNothing,
      );
    });

    testWidgets('saved correction note appears in feedback area', (
      tester,
    ) async {
      await _pumpArchiveHomeCard(tester);
      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_not_quite')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('archive_insight_feedback_correction_field')),
        _privateNote,
      );
      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_correction_save')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_insight_feedback_correction_marked')),
        findsOneWidget,
      );
      final savedNoteText = tester
          .widget<Text>(
            find.byKey(
              const Key('archive_insight_feedback_correction_saved_note'),
            ),
          )
          .data!;
      expect(savedNoteText, startsWith('Your note:'));
      expect(savedNoteText, contains('family'));
    });

    testWidgets('saved correction note appears in why panel', (tester) async {
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'archive_home_three',
        _privateNote,
      );
      await _pumpArchiveHomeCard(tester);

      await tester.tap(find.byKey(const Key('archive_insight_feedback_why')));
      await tester.pump();

      expect(
        find.byKey(const Key('archive_insight_feedback_why_correction_marked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_why_correction_note')),
        findsOneWidget,
      );
      final whyNoteText = tester
          .widget<Text>(
            find.byKey(
              const Key('archive_insight_feedback_why_correction_note'),
            ),
          )
          .data!;
      expect(whyNoteText, startsWith('Your note:'));
      expect(whyNoteText, contains('family'));
    });

    testWidgets('Hide this still suppresses only that target', (tester) async {
      await _pumpArchiveHomeCard(tester);
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'weeklyReview',
        'Unrelated note',
      );

      await tester.tap(find.byKey(const Key('archive_insight_feedback_hide')));
      await tester.pump();

      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.archiveHome,
          archiveHomeStage: ArchiveHomeStage.three,
        ),
        isTrue,
      );
      expect(
        ArchiveInsightFeedbackStore.hasCorrectionNote('weeklyReview'),
        isTrue,
      );
    });

    test('system correction copy avoids banned language', () {
      _expectNoBannedCopy([
        ArchiveInsightFeedbackCopy.correctionAffordance,
        ArchiveInsightFeedbackCopy.correctionPlaceholder,
        ArchiveInsightFeedbackCopy.correctionSaveCta,
        ArchiveInsightFeedbackCopy.correctionSkipCta,
        ArchiveInsightFeedbackCopy.correctionMarkedNotQuite,
        ArchiveInsightFeedbackCopy.correctionYourNotePrefix,
      ]);
    });
  });

  group('Correction note privacy', () {
    test('shareable archive proof does not include correction notes', () async {
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'archive_home_fivePlus',
        _privateNote,
      );
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      final shareText = proof.lines.join('\n');
      expect(
        shareText.toLowerCase(),
        isNot(contains(_privateNote.toLowerCase())),
      );
      expect(shareText.toLowerCase(), isNot(contains('your note:')));
      expect(shareText.toLowerCase(), isNot(contains('not quite right')));
    });
  });
}