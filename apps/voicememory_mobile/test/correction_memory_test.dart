import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_analytics.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_copy.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/patterns/correction_memory_card.dart';

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

Future<void> _saveCorrection(
  List<JournalEntry> entries,
  CurrentRelevanceAnswer answer,
) async {
  final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
  await CurrentRelevanceStore.instance().saveSelection(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
  );
  await CorrectionMemoryEngine.saveFromAnswer(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
    hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
      entries,
    ),
    source: 'test',
  );
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    CorrectionMemoryAnalytics.resetForTest();
    CorrectionMemoryAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/correction_memory/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/correction_memory/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    analyticsEvents.clear();
  });

  tearDown(() async {
    CorrectionMemoryAnalytics.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  group('CorrectionMemoryStore', () {
    test('saves still current correction', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.yes);
      final record = CorrectionMemoryStore.recordFor(
        CurrentRelevanceStore.proofKeyFor(entries),
      );
      expect(record?.state, CorrectionMemoryState.stillCurrent);
    });

    test('saves partly current correction', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.little);
      final record = CorrectionMemoryStore.recordFor(
        CurrentRelevanceStore.proofKeyFor(entries),
      );
      expect(record?.state, CorrectionMemoryState.partlyCurrent);
    });

    test('saves faded correction', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.notReally);
      final record = CorrectionMemoryStore.recordFor(
        CurrentRelevanceStore.proofKeyFor(entries),
      );
      expect(record?.state, CorrectionMemoryState.faded);
    });

    test('saves unsure correction', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.notSure);
      final record = CorrectionMemoryStore.recordFor(
        CurrentRelevanceStore.proofKeyFor(entries),
      );
      expect(record?.state, CorrectionMemoryState.unsure);
    });

    test('resetForTest clears local correction store', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.yes);
      await CorrectionMemoryStore.resetForTest();
      expect(CorrectionMemoryStore.cached, isEmpty);
    });
  });

  group('CorrectionMemoryEngine', () {
    test('hidden when no correction exists', () {
      expect(
        CorrectionMemoryEngine.build(
          entries: _threeRelatedEntries(),
          source: 'test',
        ),
        isNull,
      );
    });

    test('returned-after-faded state copy exists', () async {
      final now = DateTime.now();
      final entries = [
        _entry(
          '1',
          _strongRepeat,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
      ];
      await _saveCorrection(entries, CurrentRelevanceAnswer.notReally);
      final withReturn = [
        ...entries,
        _entry(
          '4',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: now,
        ),
      ];
      final result = CorrectionMemoryEngine.build(
        entries: withReturn,
        source: 'test',
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.returnedAfterFaded, isTrue);
      expect(result.body, CorrectionMemoryCopy.returnedAfterFadedBody);
    });

    test(
      'correction affects PresentDayRelevance state/copy where possible',
      () async {
        final entries = _threeRelatedEntries();
        await _saveCorrection(entries, CurrentRelevanceAnswer.notReally);
        final result = PresentDayRelevanceEngine.build(
          entries: entries,
          beliefSurfaceVisible: true,
          source: 'test',
          now: _now,
        );
        expect(result, isNotNull);
        expect(result!.relevanceState, PresentDayRelevanceState.fading);
        expect(result.stateBody, contains('background unless it returns'));
      },
    );

    test(
      'correction affects EvidenceWeighting explanation where possible',
      () async {
        final entries = _threeRelatedEntries();
        await _saveCorrection(entries, CurrentRelevanceAnswer.little);
        final result = EvidenceWeightingEngine.build(
          entries: entries,
          beliefSurfaceVisible: true,
          now: _now,
        );
        expect(result, isNotNull);
        final explanation = CorrectionMemoryEngine.evidenceExplanationFor(
          correction: result!.correctionMemory,
          fallback: 'Appeared across more than one saved moment.',
          isRepeatedState: true,
        );
        expect(explanation, contains('not as the whole story'));
      },
    );
  });

  group('CorrectionMemoryCard', () {
    Future<void> _pumpCard(
      WidgetTester tester,
      CorrectionMemoryResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CorrectionMemoryCard.test(result: result, source: 'test'),
          ),
        ),
      );
      await tester.pump();
    }

    CorrectionMemoryResult _resultForState(CorrectionMemoryState state) =>
        CorrectionMemoryResult(
          shouldShow: true,
          proofKey: '1|2|3',
          entryCount: 3,
          source: 'test',
          hasConfirmedRepeat: true,
          state: state,
          returnedAfterFaded: false,
          title: CorrectionMemoryCopy.title,
          body: CorrectionMemoryCopy.bodyFor(state),
          footer: CorrectionMemoryCopy.footer,
          differentiationLine: CorrectionMemoryCopy.differentiationLine,
        );

    testWidgets('renders "Archive correction saved"', (tester) async {
      await _pumpCard(
        tester,
        _resultForState(CorrectionMemoryState.stillCurrent),
      );
      expect(find.text(CorrectionMemoryCopy.title), findsOneWidget);
    });

    testWidgets('still current copy says fresh returns stronger evidence', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _resultForState(CorrectionMemoryState.stillCurrent),
      );
      expect(find.textContaining('fresh returns'), findsOneWidget);
    });

    testWidgets('partly copy says not the whole story', (tester) async {
      await _pumpCard(
        tester,
        _resultForState(CorrectionMemoryState.partlyCurrent),
      );
      expect(find.textContaining('whole story'), findsOneWidget);
    });

    testWidgets('faded copy says background unless it returns', (tester) async {
      await _pumpCard(tester, _resultForState(CorrectionMemoryState.faded));
      expect(
        find.textContaining('background unless it returns'),
        findsOneWidget,
      );
    });

    testWidgets('unsure copy says lightly in view', (tester) async {
      await _pumpCard(tester, _resultForState(CorrectionMemoryState.unsure));
      expect(find.textContaining('lightly in view'), findsOneWidget);
    });

    testWidgets('does not expose transcript/body/private text', (tester) async {
      await _pumpCard(
        tester,
        _resultForState(CorrectionMemoryState.stillCurrent),
      );
      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await _pumpCard(
        tester,
        _resultForState(CorrectionMemoryState.stillCurrent),
      );
      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'correction_memory_seen');
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'correction_state',
          'has_confirmed_repeat',
        ]),
      );
    });
  });

  group('CorrectionMemory copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      final blob = CorrectionMemoryCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });
  });

  group('Correction memory placement', () {
    test('record screen shows card below current relevance', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final relevanceIndex = source.indexOf('CurrentRelevanceCard(');
      final correctionIndex = source.indexOf('CorrectionMemoryCard(');
      expect(relevanceIndex, greaterThan(0));
      expect(correctionIndex, greaterThan(relevanceIndex));
    });
  });
}
