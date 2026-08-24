import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/belief_evidence/screens/belief_evidence_screen.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/belief_evidence_trail_card.dart';
import 'package:archiveme_mobile/widgets/archive/belief_history_timeline_card.dart';
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

List<JournalEntry> _fourDistinctWorkEntries() => [
  _voiceEntry(
    id: 'e1',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired.',
    createdAt: DateTime(2026, 6, 9, 12),
  ),
  _voiceEntry(
    id: 'e2',
    transcript:
        'Work kept pulling me back after I wanted to stop for the day at the office.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _voiceEntry(
    id: 'e3',
    transcript:
        'I noticed the same hurry showing up before I answered anyone at work.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _voiceEntry(
    id: 'e4',
    transcript:
        'The deadline pressure returned, but I caught it earlier this time.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fiveDistinctWorkEntriesWithContextShift() => [
  ..._fourDistinctWorkEntries(),
  _voiceEntry(
    id: 'e5',
    transcript:
        'The same hurry showed up at home with my partner after a long day at work.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

const _bannedWords = [
  'you are',
  'you always',
  'diagnosis',
  'symptom',
  'therapy',
  'mental health condition',
  'pattern found',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

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
  group('BeliefHistoryTimelineEngine', () {
    test('returns null below five usable entries', () {
      for (final count in [1, 2, 3, 4]) {
        expect(
          BeliefHistoryTimelineEngine.build(
            entries: _fourDistinctWorkEntries().sublist(0, count),
          ),
          isNull,
          reason: '$count entries should not show belief history',
        );
      }
    });

    test('four entries still allow belief update payoff but not history', () {
      expect(
        BeliefUpdatePayoffEngine.build(entries: _fourDistinctWorkEntries()),
        isNotNull,
      );
      expect(
        BeliefHistoryTimelineEngine.build(entries: _fourDistinctWorkEntries()),
        isNull,
      );
    });

    test('five usable entries with context shift shows changed title', () {
      final timeline = BeliefHistoryTimelineEngine.build(
        entries: _fiveDistinctWorkEntriesWithContextShift(),
      );
      expect(timeline, isNotNull);
      expect(timeline!.hasMeaningfulChange, isTrue);
      expect(timeline.title, 'Your archive belief changed.');
      expect(timeline.body, VisibleArchiveProofCopy.beliefHistoryBodyChanged);
      expect(
        timeline.earlierBelief,
        VisibleArchiveProofCopy.beliefHistoryEarlierOneMoment,
      );
      expect(
        timeline.currentBelief,
        VisibleArchiveProofCopy.beliefHistoryCurrentMultiContext,
      );
      expect(timeline.evidenceRows.length, greaterThanOrEqualTo(2));
      _expectNoBannedCopy([
        timeline.title,
        timeline.body,
        timeline.earlierBelief,
        timeline.currentBelief,
        timeline.whatChangedLine,
        ...timeline.evidenceRows,
      ]);
    });

    test('five weak duplicate entries show not clearly changed yet', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript: shared,
          createdAt: DateTime(2026, 6, 9),
        ),
        _voiceEntry(
          id: 'e2',
          transcript: shared,
          createdAt: DateTime(2026, 6, 10),
        ),
        _voiceEntry(
          id: 'e3',
          transcript: shared,
          createdAt: DateTime(2026, 6, 11),
        ),
        _voiceEntry(
          id: 'e4',
          transcript: shared,
          createdAt: DateTime(2026, 6, 12),
        ),
        _voiceEntry(
          id: 'e5',
          transcript: shared,
          createdAt: DateTime(2026, 6, 13),
        ),
      ];
      final timeline = BeliefHistoryTimelineEngine.build(entries: entries);
      expect(timeline, isNotNull);
      expect(timeline!.hasMeaningfulChange, isFalse);
      expect(timeline.evidenceWeak, isTrue);
      expect(timeline.body, 'Your archive belief has not clearly changed yet.');
      expect(timeline.title, 'Belief history');
    });

    test('degraded entries do not count toward five usable entries', () {
      final entries = [
        ..._fourDistinctWorkEntries(),
        _degradedVoiceEntry(id: 'e5'),
      ];
      expect(BeliefHistoryTimelineEngine.build(entries: entries), isNull);
    });

    test(
      'earlier, current, what changed, and evidence sections are populated',
      () {
        final timeline = BeliefHistoryTimelineEngine.build(
          entries: _fiveDistinctWorkEntriesWithContextShift(),
        );
        expect(timeline, isNotNull);
        expect(timeline!.earlierBelief, isNotEmpty);
        expect(timeline.currentBelief, isNotEmpty);
        expect(timeline.whatChangedLine, isNotEmpty);
        expect(timeline.evidenceRows, isNotEmpty);
        expect(timeline.earlierBelief, isNot(equals(timeline.currentBelief)));
      },
    );
  });

  group('BeliefHistoryTimelineCard', () {
    testWidgets('renders all sections at five entries', (tester) async {
      final timeline = BeliefHistoryTimelineEngine.build(
        entries: _fiveDistinctWorkEntriesWithContextShift(),
      );
      expect(timeline, isNotNull);

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefHistoryTimelineCard(timeline: timeline!),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('belief_history_timeline_card')),
        findsOneWidget,
      );
      expect(find.text('Your archive belief changed.'), findsOneWidget);
      expect(find.text('Earlier belief'), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.beliefHistoryCurrentBeliefLabel),
        findsOneWidget,
      );
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Evidence that changed it'), findsOneWidget);
      expect(
        find.byKey(const Key('belief_history_timeline_evidence_0')),
        findsOneWidget,
      );
      _expectNoBannedCopy(_visibleText(tester));
    });

    testWidgets('weak evidence shows not clearly changed body', (tester) async {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final timeline = BeliefHistoryTimelineEngine.build(
        entries: List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: shared,
            createdAt: DateTime(2026, 6, 9 + i, 12),
          ),
        ),
      );
      expect(timeline, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: BeliefHistoryTimelineCard(timeline: timeline!)),
        ),
      );
      await tester.pump();

      expect(
        find.text('Your archive belief has not clearly changed yet.'),
        findsOneWidget,
      );
      expect(find.text('Your archive belief changed.'), findsNothing);
    });
  });

  group('Evidence drilldown belief history section', () {
    testWidgets('evidence trail includes history at five entries', (
      tester,
    ) async {
      final trail = BeliefEvidenceTrailEngine.build(
        entries: _fiveDistinctWorkEntriesWithContextShift(),
      );
      expect(trail.historyTimeline, isNotNull);

      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefEvidenceTrailCard(trail: trail),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('belief_evidence_trail_history_heading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('belief_evidence_trail_history_earlier_belief')),
        findsOneWidget,
      );
    });

    testWidgets('evidence screen does not crash with too few entries', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BeliefEvidenceScreen(
            previewTrail: BeliefEvidenceTrail.insufficient(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('belief_evidence_trail_insufficient')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('belief_evidence_trail_history_heading')),
        findsNothing,
      );
    });
  });
}