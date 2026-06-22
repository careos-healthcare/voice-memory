import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/context_insights_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
      captureContextTag: captureContextTag,
    );

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) =>
    JournalEntry(
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
  group('ContextInsightsEngine', () {
    test('no tagged moments hides context insight card', () {
      final insights = ContextInsightsEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
          ),
        ],
      );
      expect(insights.showCard, isFalse);
    });

    test('one tagged moment shows one tagged moment copy', () {
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
      expect(
        insights.summaryLine,
        VisibleArchiveProofCopy.contextInsightsOneTagged,
      );
      expect(
        insights.detailLine,
        VisibleArchiveProofCopy.contextInsightsAddAnotherTagged,
      );
    });

    test('two same-tag moments show mostly one context copy', () {
      final insights = ContextInsightsEngine.build(
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
        insights.summaryLine,
        VisibleArchiveProofCopy.contextInsightsMostlyIn('Work'),
      );
      expect(
        insights.detailLine,
        VisibleArchiveProofCopy.contextInsightsAddDifferentContext,
      );
      expect(insights.cautionLine, VisibleArchiveProofCopy.contextInsightsStillThin);
    });

    test('mixed tags show across more than one context', () {
      final insights = ContextInsightsEngine.build(
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
          _voiceEntry(
            id: 'e3',
            transcript:
                'Family plans shifted again before I could catch my breath.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.family,
          ),
        ],
      );
      expect(
        insights.summaryLine,
        VisibleArchiveProofCopy.contextInsightsAcrossContexts,
      );
      expect(insights.topContexts.length, 3);
    });

    test('top contexts render with counts', () {
      final insights = ContextInsightsEngine.build(
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
            createdAt: DateTime(2026, 6, 10),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Another work moment before I could leave for the day moment three.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Home felt loud before I could settle into the evening moment one.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e5',
            transcript:
                'Home felt loud again before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 13),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e6',
            transcript:
                'Family plans shifted again before I could catch my breath.',
            createdAt: DateTime(2026, 6, 14),
            captureContextTag: CaptureContextTagIds.family,
          ),
        ],
      );
      expect(insights.topContexts.first.label, 'Work');
      expect(insights.topContexts.first.count, 3);
      expect(insights.topContexts[1].label, 'Home');
      expect(insights.topContexts[1].count, 2);
      expect(insights.topContexts[2].label, 'Family');
      expect(insights.topContexts[2].count, 1);
    });

    test('degraded tagged entries do not count', () {
      final insights = ContextInsightsEngine.build(
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
      expect(insights.summaryLine, contains('one tagged moment'));
    });

    test('untagged entries do not break engine', () {
      final insights = ContextInsightsEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Home felt loud before I could settle into the evening.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(insights.showCard, isTrue);
      expect(
        insights.summaryLine,
        VisibleArchiveProofCopy.contextInsightsAcrossContexts,
      );
    });

    test('tags do not appear in share-safe proof', () {
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
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Home felt loud before I could settle into the evening moment three.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('work:')));
      expect(shareText, isNot(contains('home:')));
    });

    test('copy avoids banned language', () {
      final insights = ContextInsightsEngine.build(
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
      _expectNoBannedCopy([
        insights.title,
        insights.subtitle,
        insights.summaryLine,
        if (insights.detailLine != null) insights.detailLine!,
        if (insights.cautionLine != null) insights.cautionLine!,
        ...insights.topContexts.map((row) => '${row.label}: ${row.count}'),
        VisibleArchiveProofCopy.contextInsightsMostlyIn('Work'),
      ]);
    });
  });

  group('ContextInsightsCard', () {
    testWidgets('hidden insights render nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ContextInsightsCard(insights: ContextInsights.hidden()),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('context_insights_card')), findsNothing);
    });

    testWidgets('top contexts render in card', (tester) async {
      final insights = ContextInsightsEngine.build(
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
                'Home felt loud before I could settle into the evening moment three.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(
            child: ContextInsightsCard(insights: insights),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('context_insights_card')), findsOneWidget);
      expect(find.text('Where this shows up'), findsOneWidget);
      expect(find.byKey(const Key('context_insights_top_work')), findsOneWidget);
      expect(find.textContaining('Work: 2 moments'), findsOneWidget);
      expect(find.textContaining('Home: 1 moment'), findsOneWidget);
    });
  });
}
