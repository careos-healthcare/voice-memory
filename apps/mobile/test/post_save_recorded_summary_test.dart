import 'package:archiveme_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_listening_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  String id = 'e1',
  String transcript = '',
  String observation = '',
  String exactLanguage = '',
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 20,
  localAudioPath: localAudioPath,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: exactLanguage,
    concreteObservation: observation,
    repeatedSignal: '',
  ),
);

void main() {
  group('postSaveRecordedSummary', () {
    test('prefers transcript over generated observation', () {
      final summary = postSaveRecordedSummary(
        _entry(
          transcript: 'I keep thinking about whether I should change teams.',
          observation: 'You sounded tired when talking about work.',
        ),
      );
      expect(summary, 'I keep thinking about whether I should change teams.');
      expect(summary.length, lessThanOrEqualTo(220));
    });

    test('uses observation when transcript is unavailable', () {
      final summary = postSaveRecordedSummary(
        _entry(observation: 'You sounded tired when talking about work.'),
      );
      expect(summary, 'You sounded tired when talking about work.');
      expect(summary.length, lessThanOrEqualTo(220));
    });

    test('skips draft placeholders and uses empty fallback', () {
      final summary = postSaveRecordedSummary(
        _entry(
          transcript:
              '[draft] Recording saved locally — transcribe when connected',
          observation:
              '[draft] Recording saved locally — transcribe when connected',
        ),
      );
      expect(summary, PostSaveRecordedSummaryCopy.emptyFallback);
    });

    test('truncates long text to about 220 characters', () {
      final long = List.filled(50, 'wordword').join(' ');
      final summary = postSaveRecordedSummary(_entry(transcript: long));
      expect(summary.length, lessThanOrEqualTo(221));
      expect(summary.endsWith('…'), isTrue);
    });
  });

  group('PostSaveListeningCard', () {
    testWidgets('shows listening copy while processing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PostSaveListeningCard()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('post_save_listening_card')), findsOneWidget);
      expect(
        find.text(PostSaveRecordedSummaryCopy.listeningTitle),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.listeningBody),
        findsOneWidget,
      );
    });
  });

  group('PostSaveRecordedSummaryCard', () {
    testWidgets('low-quality degraded card shows usable-words copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _entry(
                transcript:
                    '[draft] Recording saved locally — transcribe when connected',
                localAudioPath: '/tmp/audio.m4a',
              ),
              degradedBodyCopy: VoiceCaptureCopy.lowQualityTranscriptIssue,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_degraded_transcription_card')),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveBody),
        findsOneWidget,
      );
    });

    testWidgets('degraded voice capture shows transcription fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _entry(
                transcript:
                    '[draft] Recording saved locally — transcribe when connected',
                localAudioPath: '/tmp/audio.m4a',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_degraded_transcription_card')),
        findsOneWidget,
      );
      expect(find.text(PostSaveRecordedSummaryCopy.title), findsNothing);
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveBody),
        findsOneWidget,
      );
      expect(
        find.text(VoiceCaptureCopy.transcriptionFailedIssue),
        findsNothing,
      );
      expect(
        find.byKey(const Key('post_save_type_what_you_said')),
        findsNothing,
      );
      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
      expect(find.byKey(const Key('post_save_play_recording')), findsNothing);
      expect(find.byKey(const Key('post_save_share_audio')), findsNothing);
      await tester.tap(
        find.byKey(const Key('post_save_degraded_more_options')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post_save_play_recording')), findsOneWidget);
      expect(find.byKey(const Key('post_save_share_audio')), findsOneWidget);
    });

    testWidgets('degraded card keeps bluetooth note behind More options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _entry(
                transcript:
                    '[draft] Recording saved locally — transcribe when connected',
                localAudioPath: '/tmp/audio.m4a',
              ),
              showSilentInputWarning: true,
              onBackToRecord: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PendingTranscriptRecoveryCopy.bluetoothAccessoryNote),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const Key('post_save_degraded_more_options')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(PendingTranscriptRecoveryCopy.bluetoothAccessoryNote),
        findsOneWidget,
      );
      expect(
        find.text(VoiceCaptureCopy.silentMicrophoneInputDebugWarning),
        findsNothing,
      );
    });

    testWidgets(
      'usable transcript after typed fallback shows What ArchiveMe heard',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostSaveRecordedSummaryCard(
                entry: _entry(
                  transcript: 'I felt pressure before saying yes again.',
                  localAudioPath: '/tmp/audio.m4a',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('post_save_recorded_summary_card')),
          findsOneWidget,
        );
        expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
        expect(
          find.byKey(const Key('post_save_degraded_transcription_card')),
          findsNothing,
        );
        expect(
          find.text(VoiceCaptureCopy.transcriptionFailedIssue),
          findsNothing,
        );
        expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
      },
    );

    testWidgets('non-empty transcript shows What ArchiveMe heard', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _entry(
                transcript: 'I felt pressure before saying yes again.',
                observation: 'You mentioned pressure before saying yes.',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_recorded_summary_card')),
        findsOneWidget,
      );
      expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
      expect(
        find.text('I felt pressure before saying yes again.'),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.firstEntryFootnote),
        findsOneWidget,
      );
      expect(find.textContaining('[draft]'), findsNothing);
      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
    });

    test('postSaveHasHeardText is false for degraded voice entries', () {
      final entry = _entry(
        transcript:
            '[draft] Recording saved locally — transcribe when connected',
        localAudioPath: '/tmp/audio.m4a',
      );
      expect(postSaveHasHeardText(entry), isFalse);
      expect(postSaveIsDegradedVoiceCapture(entry), isTrue);
    });

    test('postSaveHasHeardText is true when transcript is usable', () {
      expect(
        postSaveHasHeardText(
          _entry(transcript: 'I felt pressure before saying yes again.'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'offline voice with persisted transcript shows normal insight card',
      (tester) async {
        const spoken = 'I felt pressure before saying yes again today.';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostSaveRecordedSummaryCard(
                entry: _entry(
                  transcript: spoken,
                  observation: spoken,
                  localAudioPath: '/tmp/audio.m4a',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('post_save_recorded_summary_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('post_save_degraded_transcription_card')),
          findsNothing,
        );
        expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
        expect(find.text(spoken), findsOneWidget);
        expect(
          find.text(VoiceCaptureCopy.transcriptionFailedIssue),
          findsNothing,
        );
      },
    );

    testWidgets(
      'analysis pending note shows when transcript saved without insight',
      (tester) async {
        const spoken = 'I felt pressure before saying yes again today.';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostSaveRecordedSummaryCard(
                entry: _entry(
                  transcript: spoken,
                  observation: spoken,
                  localAudioPath: '/tmp/audio.m4a',
                ),
                showAnalysisPendingNote: true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('post_save_recorded_summary_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('post_save_degraded_transcription_card')),
          findsNothing,
        );
        expect(find.text(spoken), findsOneWidget);
        expect(
          find.text(VoiceCaptureCopy.analysisUnavailableNote),
          findsOneWidget,
        );
        expect(
          find.text(VoiceCaptureCopy.transcriptionFailedIssue),
          findsNothing,
        );
      },
    );

    testWidgets('shows fallback copy when transcript and summary unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PostSaveRecordedSummaryCard(entry: _entry())),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveRecordedSummaryCopy.emptyFallback),
        findsOneWidget,
      );
    });

    testWidgets(
      'first entry shows heard but not What this added or What changed',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostSaveRecordedSummaryCard(
                entry: _entry(
                  transcript: 'I felt pressure before saying yes again.',
                ),
                allEntries: [
                  _entry(
                    transcript: 'I felt pressure before saying yes again.',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
        expect(
          find.text(PostSaveRecordedSummaryCopy.firstEntryFootnote),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
          findsNothing,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.whatChangedTitle),
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
      },
    );

    testWidgets(
      'low-signal Test save shows neutral state without repeat claims',
      (tester) async {
        final prior = _entry(
          id: 'a',
          createdAt: DateTime(2026, 6, 1, 12),
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        );
        final latest = _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript: 'Test',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostSaveRecordedSummaryCard(
                entry: latest,
                allEntries: [latest, prior],
                onAddMoreDetail: () {},
                onBackToRecord: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
        expect(find.text('Test'), findsOneWidget);
        expect(
          find.text(PostSaveRecordedSummaryCopy.lowSignalWhatThisAddedBody),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.lowSignalPrompt),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.lowSignalAddDetailCta),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.lowSignalBackToRecordCta),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.connectToRepeatLabel),
          findsNothing,
        );
        expect(
          find.text(PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel),
          findsNothing,
        );
        expect(find.textContaining('Both moments mention'), findsNothing);
        expect(
          find.textContaining('Your archive updated its belief'),
          findsNothing,
        );
        expect(find.textContaining('said yes'), findsNothing);
        expect(find.textContaining('capacity'), findsNothing);
      },
    );

    testWidgets('meaningful latest save still shows repeat connection', (
      tester,
    ) async {
      final entries = [
        _entry(
          id: 'a',
          createdAt: DateTime(2026, 6, 1, 12),
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entries.last,
              allEntries: entries,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.connectToRepeatLabel),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('post_save_what_this_added_loop')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('post_save_what_this_added_evidence')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('post_save_check_tomorrow')), findsOneWidget);
      expect(
        find.text(
          'Pressure shows up, then you say yes before checking your capacity.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatChangedTitle),
        findsNothing,
      );
    });

    testWidgets('fourth changed entry shows What changed with evidence', (
      tester,
    ) async {
      final entries = [
        _entry(
          id: 'a',
          createdAt: DateTime(2026, 6, 1, 12),
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
        ),
        _entry(
          id: 'd',
          createdAt: DateTime(2026, 6, 4, 12),
          transcript:
              'I paused before saying yes when they asked me to take on more work.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entries.last,
              allEntries: entries,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveRecordedSummaryCopy.whatChangedTitle),
        findsOneWidget,
      );
      expect(find.text(DailyMirrorCopy.whatChangedCaughtBody), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_what_changed_evidence')),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.tomorrowCheckThisLabel),
        findsOneWidget,
      );
      expect(
        find.text(DailyMirrorCopy.whatChangedNextQuestion),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
        findsNothing,
      );
    });

    testWidgets('weak evidence shows safe no-guessing copy', (tester) async {
      final entries = [
        _entry(
          id: 'a',
          transcript:
              'Today I went for a long walk in the park near home after lunch.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'I cooked pasta for dinner and watched a film alone tonight.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entries.last,
              allEntries: entries,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveRecordedSummaryCopy.noPatternReassurance),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.safeNoGuessing),
        findsNothing,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
        findsNothing,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatChangedTitle),
        findsNothing,
      );
    });

    testWidgets('does not show full transcript beyond cap', (tester) async {
      final long = List.filled(50, 'wordword').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _entry(transcript: long),
              allEntries: [_entry(transcript: long)],
            ),
          ),
        ),
      );
      await tester.pump();

      final body = tester.widget<Text>(
        find.byKey(const Key('post_save_recorded_summary_body')),
      );
      expect(body.data!.length, lessThanOrEqualTo(221));
      expect(body.data!.endsWith('…'), isTrue);
      expect(find.text(long), findsNothing);
    });

    testWidgets('sits between Reflection saved and Done for today', (
      tester,
    ) async {
      const doneEngine = DoneForTodayReceiptEngine();
      final doneReceipt = doneEngine.build(
        saved: true,
        entryCount: 1,
        now: DateTime(2026, 6, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(BeliefProductCopy.reflectionSavedTitle),
                  PostSaveRecordedSummaryCard(
                    entry: _entry(
                      transcript: 'You keep returning to the same worry.',
                    ),
                  ),
                  DoneForTodayReceiptCard(receipt: doneReceipt),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final savedTitle = find.text(BeliefProductCopy.reflectionSavedTitle);
      final summaryCard = find.byKey(
        const Key('post_save_recorded_summary_card'),
      );
      final doneCard = find.byKey(const Key('done_for_today_receipt_card'));

      expect(savedTitle, findsOneWidget);
      expect(summaryCard, findsOneWidget);
      expect(doneCard, findsOneWidget);
      expect(
        tester.getTopLeft(savedTitle).dy,
        lessThan(tester.getTopLeft(summaryCard).dy),
      );
      expect(
        tester.getTopLeft(summaryCard).dy,
        lessThan(tester.getTopLeft(doneCard).dy),
      );
      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
    });

    testWidgets('belief update primary hides inline discovery sections', (
      tester,
    ) async {
      final entries = [
        _entry(
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entries.last,
              allEntries: entries,
              primaryArchiveResult: PostSavePrimaryArchiveKind.beliefUpdate,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
      expect(
        find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle),
        findsNothing,
      );
      expect(
        find.text(PostSaveRecordedSummaryCopy.connectToRepeatLabel),
        findsNothing,
      );
    });
  });
}