import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_cost_later_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(String id, {String? transcript}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: transcript ??
          'I $_privateSnippet again and said yes with no capacity left.',
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

CapacityCostCheckinResult _visibleResult({String pendingId = 'real_0'}) =>
    CapacityCostCheckinResult(
      hasCard: true,
      showOnArchiveHome: true,
      title: CapacityCostCopy.cardTitle,
      body: CapacityCostCopy.cardBody,
      helperText: CapacityCostCopy.cardHelper,
      primaryCtaLabel: CapacityCostCopy.answerCheckinCta,
      secondaryCtaLabel: CapacityCostCopy.skipCta,
      pendingEntryId: pendingId,
      recordedCostCount: 0,
      earlyStateBody: CapacityCostCopy.earlyStateBody,
    );

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
    expect(lower, isNot(contains('voicememory')));
    expect(lower, isNot(contains('archiveme knows')));
    expect(lower, isNot(contains('you failed')));
    expect(lower, isNot(contains('bad choice')));
    expect(lower, isNot(contains('burnout')));
  }
}

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_capacity_cost_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_cost_prefs_$stamp.json',
  );
  await CapacityCostStore.resetForTest();
}

void main() {
  const costEngine = CapacityCostEngine();
  const loopEngine = CapacityLoopEngine();

  group('CapacityCostEngine', () {
    test('hidden with no real entries', () {
      final result = costEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final result = costEngine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('appears for capacity-yes user with at least one real yes moment', () {
      final entries = [_capacityEntry('real_0')];
      final result = costEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
      expect(result.title, 'Did that yes cost you later?');
      expect(result.pendingEntryId, 'real_0');
    });

    test('hidden in ScreenshotMode', () {
      final result = costEngine.build(
        CapacityCostInput(
          realSavedMomentCount: 1,
          capacityEvidenceCount: 1,
          capacityWedgeActive: true,
          sampleMode: true,
          records: const [],
          pendingEntryId: 'real_0',
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('generic users do not see card too early', () {
      final entries = [_capacityEntry('real_0')];
      final result = costEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: false,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('generic users see card with enough capacity evidence', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1'),
      ];
      final result = costEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: false,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
    });

    test('hidden when all moments already have records', () {
      final entries = [_capacityEntry('real_0')];
      final result = costEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: [
          CapacityCostRecord(
            sourceEntryId: 'real_0',
            costTypeIds: const [CapacityCostTypeIds.energy],
            status: CapacityCostRecordStatus.answered,
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
          ),
        ],
      );
      expect(result.hasCard, isFalse);
    });
  });

  group('CapacityCostStore', () {
    test('stores cost record locally and links to entry id', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityCostStore.instance().saveAnswered(
        sourceEntryId: 'entry_a',
        costTypeIds: const [CapacityCostTypeIds.time, CapacityCostTypeIds.energy],
      );

      final records = await CapacityCostStore.instance().loadAll();
      expect(records, hasLength(1));
      expect(records.first.sourceEntryId, 'entry_a');
      expect(records.first.costTypeIds, contains(CapacityCostTypeIds.time));
      expect(records.first.hasLaterCost, isTrue);
    });

    test('cost record does not store transcript text', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityCostStore.instance().saveAnswered(
        sourceEntryId: 'entry_b',
        costTypeIds: const [CapacityCostTypeIds.attention],
      );

      final json = (await CapacityCostStore.instance().loadAll()).first.toJson();
      final encoded = json.toString().toLowerCase();
      expect(encoded, isNot(contains(_privateSnippet)));
      expect(encoded, isNot(contains('transcript')));
    });

    test('skip/dismiss works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityCostStore.instance().saveSkipped(sourceEntryId: 'entry_c');
      final record = await CapacityCostStore.instance().recordForEntry('entry_c');
      expect(record!.status, CapacityCostRecordStatus.skipped);
      expect(record.hasLaterCost, isFalse);
    });
  });

  group('Capacity Loop integration', () {
    test('cost count appears on loop card when records exist', () {
      CapacityCostStore.seedForTest([
        CapacityCostRecord(
          sourceEntryId: 'real_0',
          costTypeIds: const [CapacityCostTypeIds.energy],
          status: CapacityCostRecordStatus.answered,
          createdAt: DateTime(2026, 6, 10),
          updatedAt: DateTime(2026, 6, 10),
        ),
        CapacityCostRecord(
          sourceEntryId: 'real_1',
          costTypeIds: const [CapacityCostTypeIds.time],
          status: CapacityCostRecordStatus.answered,
          createdAt: DateTime(2026, 6, 11),
          updatedAt: DateTime(2026, 6, 11),
        ),
      ]);

      final result = loopEngine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        costRecords: CapacityCostStore.cached,
      );

      expect(result.costLater, contains('Later cost recorded on 2 moments'));
      expect(result.costEvidenceLabel, contains('2 saved moments had a later cost'));
    });

    test('strengthen prompt when pending check-in and no records', () {
      CapacityCostStore.seedForTest(const []);

      final result = loopEngine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        costRecords: const [],
      );

      expect(
        result.costLater,
        CapacityLoopCopy.costLaterStrengthenPrompt,
      );
    });
  });

  group('CapacityCostLaterCard widget', () {
    testWidgets('renders check-in card copy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityCostLaterCard.test(result: _visibleResult()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('capacity_cost_later_card')), findsOneWidget);
      expect(find.text('Did that yes cost you later?'), findsOneWidget);
      expect(find.text('Answer check-in'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('hidden in screenshot mode flag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityCostLaterCard.test(
              result: _visibleResult(),
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('capacity_cost_later_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('does not expose private transcript text', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityCostLaterCard.test(result: _visibleResult()),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining(_privateSnippet), findsNothing);
    });
  });

  group('Copy safety', () {
    test('no banned copy in capacity cost strings', () {
      _expectNoBannedCopy(CapacityCostCopy.allVisibleStrings());
    });

    test('share copy does not include cost details or private notes', () {
      expect(CapacityLoopCopy.shareCopy, contains('No private entries shared'));
      expect(CapacityLoopCopy.shareCopy.toLowerCase(), isNot(contains('energy')));
      expect(CapacityLoopCopy.shareCopy.toLowerCase(), isNot(contains('resentment')));
      expect(CapacityCostCopy.shareSafeNote, isNot(contains(_privateSnippet)));
    });
  });
}
