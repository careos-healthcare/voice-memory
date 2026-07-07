import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_analytics.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_copy.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/patterns/evidence_weighting_card.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
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
      syncStatus: SyncStatus.localOnly,
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

EvidenceWeightingResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  DateTime? now,
}) {
  final built = EvidenceWeightingEngine.build(
    entries: entries,
    beliefSurfaceVisible: beliefSurfaceVisible,
    now: now ?? _now,
  );
  expect(built, isNotNull);
  return built!;
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    EvidenceWeightingAnalytics.resetForTest();
    EvidenceWeightingAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(EvidenceWeightingAnalytics.resetForTest);

  group('EvidenceWeightingEngine', () {
    test('hidden below 3 entries', () {
      expect(
        EvidenceWeightingEngine.build(
          entries: [_entry('1', _strongRepeat)],
          beliefSurfaceVisible: true,
        ),
        isNull,
      );
    });

    test('hidden without evidence or belief surface', () {
      final entries = [
        _entry('1', 'A quiet morning with coffee and no strong pattern.'),
        _entry('2', 'Another ordinary day without much to compare.'),
        _entry('3', 'Just noting the weather and a few small tasks.'),
      ];
      expect(
        EvidenceWeightingEngine.build(
          entries: entries,
          beliefSurfaceVisible: false,
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
      expect(result.hasConfirmedRepeat, isTrue);
      expect(result.shouldShow, isTrue);
    });

    test('uses repeated primary with fresh secondary for recent repeat', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(result.primaryState, EvidenceWeightState.repeated);
      expect(result.hasRecentEntry, isTrue);
      expect(result.displayStates, contains(EvidenceWeightState.fresh));
    });

    test('includes fading when repeat evidence is not recent', () {
      final result = _resultFor(_staleRepeatEntries());
      expect(result.primaryState, EvidenceWeightState.needsFreshProof);
      expect(result.displayStates, contains(EvidenceWeightState.fading));
    });

    test('includes softened when softening signal exists', () {
      final entries = _softeningEntries();
      expect(
        EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries),
        isTrue,
      );
      final result = _resultFor(entries);
      expect(result.hasSofteningSignal, isTrue);
      expect(result.displayStates, contains(EvidenceWeightState.softened));
    });

    test('uses old signal when only older context without repeat', () {
      final entries = [
        _entry(
          '1',
          'Work felt heavy today and I stayed late again.',
          createdAt: DateTime(2026, 4, 1),
        ),
        _entry(
          '2',
          'Still thinking about work pressure and saying yes too often.',
          createdAt: DateTime(2026, 4, 8),
        ),
        _entry(
          '3',
          'Another long day at work with the same tired feeling.',
          createdAt: DateTime(2026, 4, 15),
        ),
      ];
      final result = EvidenceWeightingEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(result, isNotNull);
      expect(result!.hasConfirmedRepeat, isFalse);
      expect(result.primaryState, EvidenceWeightState.oldSignal);
    });

    test('blocked during first proof payoff', () {
      final entries = _threeRelatedEntries();
      final result = _resultFor(entries);
      expect(
        EvidenceWeightingEngine.shouldShow(
          result: result,
          isZeroEntryState: false,
          isFirstRecordingState: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('blocked during What Changed question', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        EvidenceWeightingEngine.shouldShow(
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

    test('blocked during degraded post-save state', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        EvidenceWeightingEngine.shouldShow(
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
  });

  group('EvidenceWeightingCard', () {
    Future<void> _pumpCard(
      WidgetTester tester,
      EvidenceWeightingResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceWeightingCard.test(
              result: result,
              source: 'test',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders title, body, and footer', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.byKey(const Key('evidence_weighting_card')), findsOneWidget);
      expect(find.text(EvidenceWeightingCopy.title), findsOneWidget);
      expect(find.text(EvidenceWeightingCopy.body), findsOneWidget);
      expect(find.text(EvidenceWeightingCopy.footer), findsOneWidget);
    });

    testWidgets('renders Fresh state for recent evidence', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(EvidenceWeightingCopy.labelFresh), findsOneWidget);
      expect(find.text(EvidenceWeightingCopy.explanationFresh), findsOneWidget);
    });

    testWidgets('renders Repeated state for confirmed repeat', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.text(EvidenceWeightingCopy.labelRepeated), findsOneWidget);
      expect(
        find.text(EvidenceWeightingCopy.explanationRepeated),
        findsOneWidget,
      );
    });

    testWidgets('renders Fading state when quiet or stale signal exists', (
      tester,
    ) async {
      await _pumpCard(tester, _resultFor(_staleRepeatEntries()));

      expect(find.text(EvidenceWeightingCopy.labelFading), findsOneWidget);
      expect(find.text(EvidenceWeightingCopy.explanationFading), findsOneWidget);
    });

    testWidgets('renders Softened state when softening signal exists', (
      tester,
    ) async {
      await _pumpCard(tester, _resultFor(_softeningEntries()));

      expect(find.text(EvidenceWeightingCopy.labelSoftened), findsOneWidget);
      expect(
        find.text(EvidenceWeightingCopy.explanationSoftened),
        findsOneWidget,
      );
    });

    testWidgets('renders Needs fresh proof for older repeat without recent save', (
      tester,
    ) async {
      await _pumpCard(tester, _resultFor(_staleRepeatEntries()));

      expect(
        find.text(EvidenceWeightingCopy.labelNeedsFreshProof),
        findsOneWidget,
      );
      expect(
        find.text(EvidenceWeightingCopy.explanationNeedsFreshProof),
        findsOneWidget,
      );
    });

    testWidgets('differentiation line appears', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('evidence_weighting_differentiation_line')),
        findsOneWidget,
      );
      expect(
        find.text(EvidenceWeightingCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('does not include Pro CTA', (tester) async {
      await _pumpCard(tester, _resultFor(_threeRelatedEntries()));

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(ConsumerUiCopy.paywallPrimaryCta), findsNothing);
      expect(find.text('See Pro'), findsNothing);
    });
  });

  group('EvidenceWeightingAnalytics', () {
    test('metadata contains no private content', () {
      final result = _resultFor(_threeRelatedEntries());
      EvidenceWeightingAnalytics.seen(source: 'test', result: result);

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'evidence_weighting_seen');
      expect(record.props.keys, contains('entry_count'));
      expect(record.props.keys, contains('primary_state'));
      expect(record.props.keys, contains('has_confirmed_repeat'));
      expect(record.props.keys, contains('has_recent_entry'));
      expect(record.props.keys, contains('has_older_entry'));
      expect(record.props.keys, contains('has_softening_signal'));
      expect(record.props.keys, contains('has_quiet_signal'));
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
        expect(text, isNot(contains('capacity')));
      }
    });
  });

  group('Evidence weighting placement', () {
    test('patterns screen renders card before post-proof Pro bridge', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final cardIndex = source.indexOf('EvidenceWeightingCard(');
      final proBridgeIndex = source.indexOf(
        "analyticsSource: 'patterns_post_proof_pro_evidence_value'",
      );
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('record screen renders card before Pro evidence bridge', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final cardIndex = source.indexOf('showEvidenceWeightingOnRecordReady');
      final proBridgeIndex = source.indexOf('showProEvidenceValueOnRecordReady');
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('patterns card sits after current relevance card', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final relevanceIndex = source.indexOf('CurrentRelevanceCard(');
      final weightingIndex = source.indexOf('EvidenceWeightingCard(');
      expect(relevanceIndex, greaterThan(0));
      expect(weightingIndex, greaterThan(relevanceIndex));
    });
  });

  group('EvidenceWeighting copy guard', () {
    test('no therapy or monetisation claims', () {
      final blob = EvidenceWeightingCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('subscribe')));
      expect(blob, contains('not a verdict'));
    });
  });
}
