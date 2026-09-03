import 'dart:io';

import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_analytics.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_copy.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/patterns/present_day_relevance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries({DateTime? anchor}) {
  final base = anchor ?? _now;
  return [
    _entry(
      '1',
      _strongRepeat,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
    _entry(
      '2',
      'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: base.subtract(const Duration(days: 1)),
    ),
    _entry(
      '3',
      'I said yes again even though I had no capacity for one more ask.',
      createdAt: base,
    ),
  ];
}

List<JournalEntry> _staleRepeatEntries() => [
  _entry('1', _strongRepeat, createdAt: DateTime(2026, 5, 1, 12)),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 5, 3, 12),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 5, 5, 12),
  ),
];

List<JournalEntry> _softeningEntries() => [
  ..._threeRelatedEntries(anchor: _now.subtract(const Duration(days: 4))),
  _entry(
    '4',
    'Same capacity pressure came back but it felt easier to stop this time.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
];

PresentDayRelevanceResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  DateTime? now,
}) {
  final built = PresentDayRelevanceEngine.build(
    entries: entries,
    beliefSurfaceVisible: beliefSurfaceVisible,
    source: 'test',
    now: now ?? _now,
  );
  expect(built, isNotNull);
  return built!;
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    PresentDayRelevanceAnalytics.resetForTest();
    PresentDayRelevanceAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(PresentDayRelevanceAnalytics.resetForTest);

  group('PresentDayRelevanceEngine', () {
    test('hidden below 3 entries', () {
      expect(
        PresentDayRelevanceEngine.build(
          entries: [_entry('1', _strongRepeat)],
          beliefSurfaceVisible: true,
          source: 'test',
        ),
        isNull,
      );
    });

    test('shows with confirmed repeat', () {
      final entries = _threeRelatedEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
      final result = _resultFor(entries);
      expect(result.shouldShow, isTrue);
      expect(result.hasConfirmedRepeat, isTrue);
    });

    test('shows with belief surface', () {
      final entries = [
        _entry('1', 'Team sync ran long and I stayed quiet again.'),
        _entry('2', 'Another meeting where I held back what I wanted to say.'),
        _entry('3', 'I did not speak up in the group discussion today.'),
      ];
      final result = PresentDayRelevanceEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(result, isNotNull);
      expect(result!.hasBeliefSurface, isTrue);
      expect(result.shouldShow, isTrue);
    });

    test('current state copy for recent repeat', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(result.relevanceState, PresentDayRelevanceState.current);
      expect(result.stateBody, PresentDayRelevanceCopy.currentStateBody);
    });

    test('fading/old state copy gives less weight', () {
      final result = _resultFor(_staleRepeatEntries());
      expect(result.relevanceState, PresentDayRelevanceState.fading);
      expect(result.stateBody, PresentDayRelevanceCopy.fadingStateBody);
    });

    test('softened state copy says changing', () {
      final result = _resultFor(_softeningEntries());
      expect(result.relevanceState, PresentDayRelevanceState.softened);
      expect(result.stateBody, PresentDayRelevanceCopy.softenedStateBody);
    });

    test('unclear state copy says lightly in view', () {
      const result = PresentDayRelevanceResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: false,
        relevanceState: PresentDayRelevanceState.unclear,
        title: PresentDayRelevanceCopy.title,
        body: PresentDayRelevanceCopy.primaryBody,
        stateBody: PresentDayRelevanceCopy.unclearStateBody,
        footer: PresentDayRelevanceCopy.footer,
        differentiationLine: PresentDayRelevanceCopy.differentiationLine,
      );
      expect(result.stateBody, PresentDayRelevanceCopy.unclearStateBody);
    });

    test('hidden during degraded transcript/post-save', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        PresentDayRelevanceEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
      expect(
        PresentDayRelevanceEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during active What Changed', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        PresentDayRelevanceEngine.shouldShowOnRecordReady(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });
  });

  group('PresentDayRelevanceCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      PresentDayRelevanceResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentDayRelevanceCard.test(result: result, source: 'test'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders title "Why this may matter now"', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('present_day_relevance_card')),
        findsOneWidget,
      );
      expect(find.text(PresentDayRelevanceCopy.title), findsOneWidget);
    });

    testWidgets('renders "not important just because it happened before"', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.textContaining('not important just because it happened before'),
        findsOneWidget,
      );
    });

    testWidgets('renders "Your past is context, not a verdict."', (
      tester,
    ) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(PresentDayRelevanceCopy.footer), findsOneWidget);
    });

    testWidgets('renders ChatGPT differentiation line', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('present_day_relevance_differentiation_line')),
        findsOneWidget,
      );
      expect(
        find.text(PresentDayRelevanceCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('does not expose transcript/body/private text', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('does not include Pro CTA', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
    });

    testWidgets('analytics metadata only', (tester) async {
      await pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'present_day_relevance_seen');
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_belief_surface',
          'relevance_state',
        ]),
      );
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
      }
    });
  });

  group('Present day relevance placement', () {
    test('patterns screen renders card before post-proof Pro bridge', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final cardIndex = source.indexOf('PresentDayRelevanceCard(');
      final proBridgeIndex = source.indexOf(
        "analyticsSource: 'patterns_post_proof_pro_evidence_value'",
      );
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('patterns card sits after proof specificity card', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final specificityIndex = source.indexOf('ProofSpecificityCard(');
      final relevanceIndex = source.indexOf('PresentDayRelevanceCard(');
      expect(specificityIndex, greaterThan(0));
      expect(relevanceIndex, greaterThan(specificityIndex));
    });
  });

  group('PresentDayRelevance copy guard', () {
    test('no therapy or monetisation claims', () {
      final blob = PresentDayRelevanceCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('subscribe')));
      expect(blob, contains('chatgpt'));
      expect(blob, contains('not a verdict'));
    });
  });
}
