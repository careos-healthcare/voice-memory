import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/context_aware_archive_copy.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/next_moment_prompt.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
  captureContextTag: captureContextTag,
);

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) => JournalEntry(
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
  captureContextTag: captureContextTag,
);

List<JournalEntry> _distinctEntries(int count) => List.generate(
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
  'share to unlock',
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
  group('ContextAwareArchiveCopyEngine', () {
    test('no tags leaves existing copy unchanged', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: _distinctEntries(3),
      );
      expect(copy.showLines, isFalse);

      final summary = ArchiveHomeSummaryEngine.build(
        entries: _distinctEntries(3),
      );
      expect(summary.contextAwareSummaryLine, isNull);
      expect(summary.contextAwareDetailLine, isNull);
    });

    test('one tag shows thin context evidence copy', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(copy.showLines, isTrue);
      expect(copy.summaryLine, VisibleArchiveProofCopy.contextAwareStillThin);
      expect(copy.detailLine, isNull);
    });

    test('two same tags shows mostly one context copy', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(
        copy.summaryLine,
        VisibleArchiveProofCopy.contextAwareMostlyAt(CaptureContextTagIds.work),
      );
      expect(
        copy.detailLine,
        VisibleArchiveProofCopy.contextAwareAddDifferentContext,
      );
    });

    test('mixed tags shows across more than one context copy', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(
        copy.summaryLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
      );
      expect(
        copy.detailLine,
        VisibleArchiveProofCopy.contextAwareCompareAcross('Home', 'Work'),
      );
    });

    test('only up to two friendly labels are named', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 10),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Family plans shifted again before I could catch my breath moment three.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.family,
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Money worries showed up again before I opened my messages today.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.money,
          ),
        ],
      );
      expect(copy.detailLine, contains('Family'));
      expect(copy.detailLine, contains('Home'));
      expect(copy.detailLine, isNot(contains('Money')));
      expect(copy.detailLine, isNot(contains('Work')));
    });

    test('context tags do not appear in share-safe proof', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('work:')));
      expect(shareText, isNot(contains('home:')));
    });

    test('degraded tagged entries do not count', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.home),
        ],
      );
      expect(copy.summaryLine, VisibleArchiveProofCopy.contextAwareStillThin);
    });

    test('copy avoids banned language', () {
      final copy = ContextAwareArchiveCopyEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      _expectNoBannedCopy([
        if (copy.summaryLine != null) copy.summaryLine!,
        if (copy.detailLine != null) copy.detailLine!,
        VisibleArchiveProofCopy.contextAwareMostlyAt(CaptureContextTagIds.work),
        VisibleArchiveProofCopy.contextAwareCompareAcross('Work', 'Home'),
      ]);
    });
  });

  group('Context-aware surface integrations', () {
    test('weekly review uses context-aware uncertainty lines', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: [
          ..._distinctEntries(4),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Home felt loud before I could settle into the evening with family nearby.',
            createdAt: DateTime(2026, 6, 13),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e5',
            transcript:
                'Money worries showed up again before I opened my messages today.',
            createdAt: DateTime(2026, 6, 14),
            captureContextTag: CaptureContextTagIds.money,
          ),
        ],
      );
      expect(
        review.uncertaintyLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
      );
      expect(review.contextAwareDetailLine, contains('Money'));
    });

    test('next moment prompt appends context-aware body lines', () {
      final prompt = NextMomentPromptEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(prompt!.body, contains('mostly showing up at work'));
      expect(prompt.body, contains('different context'));
    });

    test(
      'archive health action plan adds context summary without duplicate detail',
      () {
        final plan = ArchiveHealthActionPlanEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I felt pressure at work before saying yes again even when I was tired moment one.',
              captureContextTag: CaptureContextTagIds.work,
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Work kept pulling me back after I wanted to stop for the day moment two.',
              createdAt: DateTime(2026, 6, 11),
              captureContextTag: CaptureContextTagIds.work,
            ),
            _voiceEntry(
              id: 'e3',
              transcript:
                  'I noticed the same hurry showing up before I answered anyone moment three.',
              createdAt: DateTime(2026, 6, 12),
              captureContextTag: CaptureContextTagIds.work,
            ),
          ],
        );
        expect(
          plan.contextAwareSummaryLine,
          contains('mostly showing up at work'),
        );
        expect(plan.contextAwareDetailLine, isNull);
      },
    );

    test('belief history adds context-aware lines when tags exist', () {
      final timeline = BeliefHistoryTimelineEngine.build(
        entries: [
          ..._distinctEntries(4),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Home felt loud before I could settle into the evening with family nearby.',
            createdAt: DateTime(2026, 6, 13, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e5',
            transcript:
                'Money worries showed up again before I opened my messages today.',
            createdAt: DateTime(2026, 6, 14, 12),
            captureContextTag: CaptureContextTagIds.money,
          ),
        ],
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.contextAwareSummaryLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
      );
      expect(timeline.contextAwareDetailLine, isNotNull);
    });

    test('existing Context Insights tests still pass shape', () {
      final insights = ContextInsightsEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(insights.showCard, isTrue);
      expect(insights.title, VisibleArchiveProofCopy.contextInsightsTitle);
    });
  });
}