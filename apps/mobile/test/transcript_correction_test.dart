import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_engine.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_analytics.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_controller.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_history/archive_history_sheet.dart';
import 'package:archiveme_mobile/widgets/record/correct_transcript_sheet.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _textEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 24,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

JournalEntry _degradedVoiceEntry({
  String id = 'v1',
  String transcript = _placeholder,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 20,
  localAudioPath: '/tmp/audio.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.pendingUpload,
);

void main() {
  late TestStorageSandbox sandbox;
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((event, props) {
      analyticsEvents.add((event: event, props: props));
    });
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  group('TranscriptCorrectionCopy', () {
    test('spec copy is stable', () {
      expect(TranscriptCorrectionCopy.actionLabel, 'Correct transcript');
      expect(TranscriptCorrectionCopy.sheetTitle, 'Correct transcript');
      expect(TranscriptCorrectionCopy.sheetHelper, contains('future patterns'));
      expect(TranscriptCorrectionCopy.inputLabel, 'What you meant to say');
      expect(TranscriptCorrectionCopy.saveButton, 'Save correction');
      expect(TranscriptCorrectionCopy.cancelButton, 'Cancel');
      expect(TranscriptCorrectionCopy.savedSuccess, 'Transcript corrected');
    });
  });

  group('TranscriptCorrectionGate', () {
    test('allows correction for saved transcript text', () {
      expect(
        TranscriptCorrectionGate.entryAllowsCorrection(
          _textEntry(
            id: 't1',
            transcript:
                "I said yes when I didn't have the cockpit's capability left today.",
          ),
        ),
        isTrue,
      );
    });

    test('blocks empty and placeholder entries', () {
      expect(
        TranscriptCorrectionGate.entryAllowsCorrection(
          _textEntry(id: 'empty', transcript: ''),
        ),
        isFalse,
      );
      expect(
        TranscriptCorrectionGate.entryAllowsCorrection(_degradedVoiceEntry()),
        isFalse,
      );
    });

    test('pending transcript uses Add words path only', () {
      expect(
        PendingTranscriptRecoveryGate.entryNeedsRecovery(_degradedVoiceEntry()),
        isTrue,
      );
      expect(
        TranscriptCorrectionGate.entryAllowsCorrection(_degradedVoiceEntry()),
        isFalse,
      );
    });
  });

  group('TranscriptCorrectionController', () {
    test('saving correction updates displayed transcript', () async {
      const misheard =
          "I said yes when I didn't have the cockpit's capability left today.";
      const corrected =
          'I said yes again before checking capacity at work today.';

      await AppServices.instance.journalStore.save(
        _textEntry(id: 'fix1', transcript: misheard),
      );

      final saved = await TranscriptCorrectionController.apply(
        entry: _textEntry(id: 'fix1', transcript: misheard),
        correctedText: corrected,
      );

      expect(saved.id, 'fix1');
      expect(saved.createdAt, DateTime(2026, 6, 12, 10));
      expect(saved.transcript, corrected);

      final reloaded = await AppServices.instance.journalStore.getById('fix1');
      expect(reloaded!.transcript, corrected);
      expect(ComparableEvidenceText.userText(reloaded), corrected);
    });

    test('corrected real text can ground repeat evidence', () async {
      const misheard =
          "I said yes when I didn't have the cockpit's capability left today.";
      const corrected =
          'I said yes again before checking capacity at work today.';

      await AppServices.instance.journalStore.save(
        _textEntry(
          id: 'a',
          transcript: misheard,
          createdAt: DateTime(2026, 6, 11, 12),
        ),
      );
      await AppServices.instance.journalStore.save(
        _textEntry(
          id: 'b',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      );

      const engine = SecondSessionSignalEngine();
      final before = await AppServices.instance.journalStore.loadAll();
      expect(misheard.toLowerCase(), isNot(contains('checking capacity')));

      await TranscriptCorrectionController.apply(
        entry: before.firstWhere((e) => e.id == 'a'),
        correctedText: corrected,
      );

      final after = await AppServices.instance.journalStore.loadAll();
      final correctedEntry = after.firstWhere((e) => e.id == 'a');
      expect(correctedEntry.transcript, corrected);
      expect(engine.hasGroundedRepeatMatch(after), isTrue);

      final comparison = engine.build(after);
      expect(comparison.possibleRepeat, isTrue);
      expect(
        '${comparison.whatRepeated} ${comparison.latestSignalLabel}',
        anyOf(
          contains('checking capacity'),
          contains('checking your capacity'),
          contains('saying yes'),
        ),
      );
    });

    test('generic corrected text remains ignored by quality gate', () async {
      await AppServices.instance.journalStore.save(
        _textEntry(id: 'g', transcript: 'A real moment about work pressure.'),
      );

      final updated = await TranscriptCorrectionController.apply(
        entry: _textEntry(
          id: 'g',
          transcript: 'A real moment about work pressure.',
        ),
        correctedText: 'hello checking mic test',
      );

      final verdict = ArchiveEvidenceQuality.assess(updated);
      expect(verdict.allowsInsights, isFalse);
      expect(
        verdict.level,
        anyOf(
          ArchiveEvidenceQualityLevel.weak,
          ArchiveEvidenceQualityLevel.unusable,
        ),
      );
    });
  });

  group('CorrectTranscriptSheet', () {
    testWidgets('shows correction copy with prefilled transcript', (
      tester,
    ) async {
      const misheard =
          "I said yes when I didn't have the cockpit's capability left today.";
      final entry = _textEntry(id: 'sheet1', transcript: misheard);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CorrectTranscriptSheet(
              entry: entry,
              source: 'test',
              entryCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('correct_transcript_sheet')), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.sheetTitle), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.sheetHelper), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.inputLabel), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.saveButton), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.cancelButton), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('correct_transcript_input')),
            )
            .controller!
            .text,
        misheard,
      );
    });
  });

  group('PostSaveRecordedSummaryCard', () {
    testWidgets('shows Correct transcript for heard text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _textEntry(
                id: 'heard',
                transcript:
                    "I said yes when I didn't have the cockpit's capability left today.",
              ),
              onCorrectTranscript: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_correct_transcript_button')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Correct transcript opens sheet', (tester) async {
      final entry = _textEntry(
        id: 'tap',
        transcript:
            "I said yes when I didn't have the cockpit's capability left today.",
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entry,
              onCorrectTranscript: () async {
                await TranscriptCorrection.open(
                  tester.element(find.byType(Scaffold)),
                  entry: entry,
                  source: 'test_post_save',
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('post_save_correct_transcript_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('correct_transcript_sheet')), findsOneWidget);
    });

    testWidgets('degraded pending entry does not show Correct transcript', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _degradedVoiceEntry(),
              onCorrectTranscript: () {},
              onAddWhatYouSaid: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsNothing);
      expect(
        find.byKey(const Key('post_save_degraded_transcription_card')),
        findsOneWidget,
      );
    });
  });

  group('ArchiveHistorySheet correction', () {
    test('saved entry exposes Correct transcript CTA in engine output', () async {
      await AppServices.instance.journalStore.save(
        _textEntry(
          id: 'hist1',
          transcript:
              "I said yes when I didn't have the cockpit's capability left today.",
        ),
      );

      final content = ArchiveHistoryEngine.build(
        entries: await AppServices.instance.journalStore.loadAll(),
      );

      expect(content.items.single.showCorrectTranscriptCta, isTrue);
      expect(content.items.single.showAddWordsCta, isFalse);
    });

    testWidgets('saved entry row shows Correct transcript button', (
      tester,
    ) async {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(
            id: 'hist1',
            transcript:
                "I said yes when I didn't have the cockpit's capability left today.",
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_history_correct_transcript_hist1')),
        findsOneWidget,
      );
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsOneWidget);
    });

    testWidgets('pending entry shows Add words not Correct transcript', (
      tester,
    ) async {
      final content = ArchiveHistoryEngine.build(
        entries: [_degradedVoiceEntry(id: 'pending')],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_history_add_words_pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_history_correct_transcript_pending')),
        findsNothing,
      );
    });
  });

  group('TranscriptCorrectionAnalytics', () {
    test('tracks safe fields only — no user text', () async {
      analyticsEvents.clear();

      TranscriptCorrectionAnalytics.opened(
        source: 'test',
        entryCount: 1,
        hasParentEntry: true,
      );
      TranscriptCorrectionAnalytics.saved(
        source: 'test',
        entryCount: 1,
        hasParentEntry: true,
      );

      final events = analyticsEvents
          .where(
            (e) =>
                e.event == TranscriptCorrectionAnalytics.openedEvent ||
                e.event == TranscriptCorrectionAnalytics.savedEvent,
          )
          .toList();

      expect(events, hasLength(2));
      for (final captured in events) {
        for (final entry in captured.props.entries) {
          if (entry.key == 'reason') continue;
          final value = entry.value;
          if (value is String) {
            expect(value.toLowerCase(), isNot(contains('cockpit')));
            expect(value.toLowerCase(), isNot(contains('checking capacity')));
          }
        }
      }
    });
  });
}