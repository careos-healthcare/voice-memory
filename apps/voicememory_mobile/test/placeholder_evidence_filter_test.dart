import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/daily_question/adaptive_daily_question_engine.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_analytics.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:voicememory_mobile/features/archive_evidence/transcript_pending_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_change_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/features/interpretation/interpretation_quality_engine.dart';
import 'package:voicememory_mobile/features/timeline/timeline_entry_display.dart';
import 'package:voicememory_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_transcript_pending_view.dart';
import 'package:voicememory_mobile/widgets/record/post_save_recorded_summary_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _realText =
    'I felt pressure to say yes again before checking my capacity today.';
const _aiObservation =
    'I felt pressure to say yes before checking my capacity again today.';

JournalEntry _voicePlaceholder({String observation = ''}) => JournalEntry(
  id: 'v1',
  createdAt: DateTime(2026, 6, 12),
  transcript: _placeholder,
  durationSeconds: 20,
  localAudioPath: '/tmp/audio.m4a',
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: observation,
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

JournalEntry _textEntry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 10 + id.hashCode % 5),
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

void main() {
  group('ComparableEvidenceText', () {
    test('placeholder draft is not comparable user text', () {
      expect(ComparableEvidenceText.userText(_voicePlaceholder()), isEmpty);
      expect(
        ComparableEvidenceText.entryHasPendingTranscript(_voicePlaceholder()),
        isTrue,
      );
    });

    test('AI observation ignored when voice transcript is placeholder', () {
      final entry = _voicePlaceholder(observation: _aiObservation);
      expect(ComparableEvidenceText.userText(entry), isEmpty);
      expect(ArchiveEvidenceGuard.hasUsableReflectionText(entry), isFalse);
    });

    test('text-only placeholder with AI observation is not eligible', () {
      final entry = _textEntry('t1', _placeholder);
      final withAi = JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: entry.transcript,
        durationSeconds: entry.durationSeconds,
        reflection: Reflection(
          mood: entry.reflection.mood,
          emotionalIntensity: entry.reflection.emotionalIntensity,
          recurringThemes: entry.reflection.recurringThemes,
          exactLanguagePattern: entry.reflection.exactLanguagePattern,
          concreteObservation: _aiObservation,
          repeatedSignal: entry.reflection.repeatedSignal,
        ),
        syncStatus: entry.syncStatus,
      );
      expect(ArchiveEvidenceGuard.hasUsableReflectionText(withAi), isFalse);
    });

    test('real typed text is still used normally', () {
      final entry = _textEntry('real', _realText);
      expect(ComparableEvidenceText.userText(entry), _realText);
      expect(ArchiveEvidenceGuard.hasUsableReflectionText(entry), isTrue);
    });

    test('mixed entries ignore placeholder and keep real entries', () {
      final entries = [
        _voicePlaceholder(observation: _aiObservation),
        _textEntry('2', _realText),
        _textEntry(
          '3',
          'Another long enough reflection about saying yes again.',
        ),
      ];
      final eligible = ArchiveEvidenceGuard.eligibleEntries(
        entries,
        analyticsSource: 'test',
      );
      expect(eligible.length, 2);
      expect(
        eligible.every((e) => !e.transcript.startsWith('[draft]')),
        isTrue,
      );
    });
  });

  group('EarlyFirstSignalEngine placeholder filtering', () {
    test('does not build early signal from placeholder-only evidence', () {
      final entries = List.generate(
        3,
        (i) => _voicePlaceholder(observation: _aiObservation),
      );
      expect(EarlyFirstSignalEngine.build(entries: entries), isNull);
    });

    test('confirmed repeat cannot form from placeholder text', () {
      final entries = List.generate(
        3,
        (i) => _voicePlaceholder(observation: _aiObservation),
      );
      expect(
        ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases,
        isEmpty,
      );
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(entries),
        isFalse,
      );
    });
  });

  group('InterpretationQualityEngine placeholder filtering', () {
    test('does not surface From your moment reads for placeholder entry', () {
      final result = const InterpretationQualityEngine().build(
        latestEntry: _voicePlaceholder(observation: _aiObservation),
      );
      expect(result.reads, isEmpty);
      expect(result.needsClearerMoment, isTrue);
    });
  });

  group('Archive insight engines placeholder filtering', () {
    test('archive current belief ignores placeholder-only entries', () {
      final entries = List.generate(
        3,
        (i) => _voicePlaceholder(observation: _aiObservation),
      );
      final belief = ArchiveCurrentBeliefEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(belief, isNull);
    });

    test(
      'adaptive daily question does not extract phrase from placeholder',
      () {
        final entries = List.generate(
          3,
          (i) => _voicePlaceholder(observation: _aiObservation),
        );
        final question = AdaptiveDailyQuestionEngine.build(entries: entries);
        expect(question?.usesPhrase, isNot(true));
        expect(question?.questionText.contains('[draft]'), isNot(true));
        expect(
          question?.questionText.contains('transcribe when connected'),
          isNot(true),
        );
      },
    );

    test('private archive report excludes placeholder evidence', () {
      final report = PrivateArchiveReportEngine.build(
        entries: List.generate(
          3,
          (i) => _voicePlaceholder(observation: _aiObservation),
        ),
      );
      expect(report, isNull);
    });

    test('evidence timeline excludes placeholder evidence', () {
      final timeline = ArchiveChangeTimelineEngine.build(
        entries: List.generate(
          3,
          (i) => _voicePlaceholder(observation: _aiObservation),
        ),
      );
      expect(timeline, isNull);
    });
  });

  group('UI fallback copy', () {
    testWidgets('Patterns shows transcript pending fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsTranscriptPendingView(savedEntryId: 'v1'),
          ),
        ),
      );

      expect(
        find.text(TranscriptPendingCopy.patternsSavedTitle),
        findsOneWidget,
      );
      expect(
        find.text(TranscriptPendingCopy.patternsSavedBody),
        findsOneWidget,
      );
      expect(find.textContaining('[draft]'), findsNothing);
      expect(find.textContaining('Saying yes'), findsNothing);
    });

    testWidgets('Record post-save shows transcript pending copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(entry: _voicePlaceholder()),
          ),
        ),
      );

      expect(find.text(PendingTranscriptRecoveryCopy.title), findsOneWidget);
      expect(find.text(PendingTranscriptRecoveryCopy.body), findsOneWidget);
      expect(find.textContaining('[draft]'), findsNothing);
      expect(
        find.textContaining(ConsumerUiCopy.postSaveInsightFeelsTrue),
        findsNothing,
      );
    });

    test('entry detail pending view uses neutral recovery copy', () {
      final view = entryDetailRecordedView(_voicePlaceholder());
      expect(view.primary, TranscriptPendingCopy.savedLocallyTitle);
      expect(view.secondary, TranscriptPendingCopy.savedLocallyBody);
      expect(view.isPendingTranscript, isTrue);
    });
  });

  test('isDraftOrSystemTranscriptPlaceholder blocks required variants', () {
    expect(isDraftOrSystemTranscriptPlaceholder(_placeholder), isTrue);
    expect(
      isDraftOrSystemTranscriptPlaceholder(
        CaptureSaveMessages.recordingSavedLocally,
      ),
      isTrue,
    );
    expect(
      isDraftOrSystemTranscriptPlaceholder('transcribe when connected'),
      isTrue,
    );
    expect(isDraftOrSystemTranscriptPlaceholder('[draft]'), isTrue);
    expect(
      isDraftOrSystemTranscriptPlaceholder(
        'I saved locally on my phone when I moved last year.',
      ),
      isFalse,
    );
  });

  test('analytics event name is stable', () {
    expect(
      ArchiveEvidenceAnalytics.skippedPlaceholderEvent,
      'archive_evidence_skipped_placeholder',
    );
    expect(
      ArchiveEvidenceAnalytics.skippedPlaceholderReason,
      'placeholder_or_pending_transcript',
    );
  });
}
