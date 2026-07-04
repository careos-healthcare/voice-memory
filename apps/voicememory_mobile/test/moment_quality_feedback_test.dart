import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/moment_quality/moment_quality_feedback_copy.dart';
import 'package:voicememory_mobile/features/moment_quality/moment_quality_feedback_engine.dart';
import 'package:voicememory_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/moment_quality_feedback_card.dart';
import 'package:voicememory_mobile/widgets/record/post_save_recorded_summary_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

const _specificMoment =
    'I felt pressure to say yes again before checking my capacity today.';
const _shortMoment = 'tired';

JournalEntry _textEntry({
  required String id,
  required String transcript,
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
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
      syncStatus: SyncStatus.localOnly,
    );

JournalEntry _pendingVoiceEntry({String transcript = _placeholder}) =>
    JournalEntry(
      id: 'v1',
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

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _textEntry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
      ),
      _textEntry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
      ),
      _textEntry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
      ),
    ];

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('MomentQualityFeedbackCopy', () {
    test('spec copy is stable', () {
      expect(
        MomentQualityFeedbackCopy.specificUsableTitle,
        'Good moment for your archive',
      );
      expect(
        MomentQualityFeedbackCopy.tooShortBody,
        contains('too short for patterns'),
      );
      expect(
        MomentQualityFeedbackCopy.quietDayTitle,
        'Saved as a quiet day',
      );
      expect(
        MomentQualityFeedbackCopy.genericTestBody,
        'Saved, but not used for patterns.',
      );
      expect(
        MomentQualityFeedbackCopy.pendingTranscriptBody,
        contains('Add what you said'),
      );
    });

    test('no advice therapy or internal quality labels', () {
      final joined =
          MomentQualityFeedbackCopy.allVisibleCopy().join(' ').toLowerCase();
      expect(joined, isNot(contains('weak')));
      expect(joined, isNot(contains('unusable')));
      expect(joined, isNot(contains('bad')));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('therapy')));
      expect(joined, isNot(contains('revenuecat')));
      expect(ProofSurfaceAdviceGuard.passes(joined), isTrue);
    });
  });

  group('MomentQualityFeedbackEngine', () {
    test('specific real moment shows good moment copy', () {
      final result = MomentQualityFeedbackEngine.build(
        entry: _textEntry(id: 'u', transcript: _specificMoment),
      );
      expect(result?.kind, MomentQualityFeedbackKind.specificUsable);
      expect(result?.title, MomentQualityFeedbackCopy.specificUsableTitle);
      expect(result?.body, MomentQualityFeedbackCopy.specificUsableBody);
    });

    test('vague short entry shows saved but may be too short', () {
      final result = MomentQualityFeedbackEngine.build(
        entry: _textEntry(id: 's', transcript: _shortMoment),
      );
      expect(result?.kind, MomentQualityFeedbackKind.tooShortVague);
      expect(result?.title, MomentQualityFeedbackCopy.savedTitle);
      expect(result?.body, MomentQualityFeedbackCopy.tooShortBody);
    });

    test('quiet day shows quiet-day copy', () {
      final result = MomentQualityFeedbackEngine.build(
        entry: _textEntry(
          id: 'q',
          transcript: RecordCaptureModeEngine.quietDaySaveText(),
        ),
      );
      expect(result?.kind, MomentQualityFeedbackKind.quietDay);
      expect(result?.title, MomentQualityFeedbackCopy.quietDayTitle);
      expect(result?.body, MomentQualityFeedbackCopy.quietDayBody);
    });

    test('generic test text shows saved but not used for patterns', () {
      final result = MomentQualityFeedbackEngine.build(
        entry: _textEntry(id: 'g', transcript: 'hello checking mic test'),
      );
      expect(result?.kind, MomentQualityFeedbackKind.genericTest);
      expect(result?.title, MomentQualityFeedbackCopy.savedTitle);
      expect(result?.body, MomentQualityFeedbackCopy.genericTestBody);
    });

    test('pending transcript asks to add words', () {
      final result = MomentQualityFeedbackEngine.build(
        entry: _pendingVoiceEntry(),
      );
      expect(result?.kind, MomentQualityFeedbackKind.pendingTranscript);
      expect(result?.title, MomentQualityFeedbackCopy.savedTitle);
      expect(result?.body, MomentQualityFeedbackCopy.pendingTranscriptBody);
    });
  });

  group('MomentQualityFeedbackGates', () {
    test('hidden during first proof moment', () {
      expect(
        MomentQualityFeedbackGates.shouldShow(
          entry: _textEntry(id: 'u', transcript: _specificMoment),
          showFirstProofMoment: true,
          hierarchyAllowsFeedback: true,
        ),
        isFalse,
      );
    });

    test('hidden for degraded voice capture', () {
      final degraded = _pendingVoiceEntry();
      expect(
        MomentQualityFeedbackGates.shouldShow(
          entry: degraded,
          showFirstProofMoment: false,
          hierarchyAllowsFeedback: true,
        ),
        isFalse,
      );
    });

    test('hidden when hierarchy suppresses feedback', () {
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: _threeRelatedRepeatEntries(),
        suppressLatestSaveArchiveInsight: false,
        firstProofUnlocked: true,
      );
      expect(hierarchy.showMomentQualityFeedback, isFalse);
      expect(
        MomentQualityFeedbackGates.shouldShow(
          entry: _threeRelatedRepeatEntries().last,
          showFirstProofMoment: false,
          hierarchyAllowsFeedback: hierarchy.showMomentQualityFeedback,
        ),
        isFalse,
      );
    });
  });

  group('MomentQualityFeedbackCard', () {
    testWidgets('renders specific usable feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentQualityFeedbackCard(
              entry: _textEntry(id: 'u', transcript: _specificMoment),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('moment_quality_feedback_card_specificUsable')),
        findsOneWidget,
      );
      expect(
        find.text(MomentQualityFeedbackCopy.specificUsableTitle),
        findsOneWidget,
      );
      expect(
        find.text(MomentQualityFeedbackCopy.specificUsableBody),
        findsOneWidget,
      );
    });
  });

  group('Post-save integration', () {
    testWidgets('feedback appears below summary card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                PostSaveRecordedSummaryCard(
                  entry: _textEntry(id: 'u', transcript: _specificMoment),
                ),
                MomentQualityFeedbackCard(
                  entry: _textEntry(id: 'u', transcript: _specificMoment),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('post_save_recorded_summary_card')), findsOneWidget);
      expect(
        find.byKey(const Key('moment_quality_feedback_card_specificUsable')),
        findsOneWidget,
      );
    });

    testWidgets('transcript correction action still available on summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _textEntry(id: 'u', transcript: _specificMoment),
              onCorrectTranscript: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('post_save_correct_transcript_button')),
        findsOneWidget,
      );
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsOneWidget);
    });
  });

  group('First proof unchanged', () {
    test('first proof still builds with feedback shipped', () {
      final moment = FirstProofMomentEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(moment, isNotNull);
      expect(moment!.hasStrongEvidence, isTrue);
    });
  });

  group('First proof clutter guard', () {
    test('feedback hidden when first proof moment is showing', () {
      expect(
        MomentQualityFeedbackGates.shouldShow(
          entry: _threeRelatedRepeatEntries().last,
          showFirstProofMoment: true,
          hierarchyAllowsFeedback: true,
        ),
        isFalse,
      );
    });

    test('first proof unlock suppresses feedback via hierarchy', () {
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: _threeRelatedRepeatEntries(),
        suppressLatestSaveArchiveInsight: false,
        firstProofUnlocked: true,
      );
      expect(hierarchy.kind, PostSavePrimaryArchiveKind.firstProofUnlocked);
      expect(hierarchy.showMomentQualityFeedback, isFalse);
    });

    test('feedback allowed on ordinary first save', () {
      expect(
        MomentQualityFeedbackGates.shouldShow(
          entry: _textEntry(id: 'u', transcript: _specificMoment),
          showFirstProofMoment: false,
          hierarchyAllowsFeedback: true,
        ),
        isTrue,
      );
    });
  });
}
