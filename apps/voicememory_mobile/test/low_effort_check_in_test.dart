import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/low_effort_check_in_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/low_effort_check_in_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/low_effort_check_in_card.dart';
import 'package:voicememory_mobile/widgets/record/one_small_recording_card.dart';

import 'support/memory_pressure_stores.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// A connected work-context thread.
List<PressureCheckInRecord> _workThread3() => [
  _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
  _record(
    id: 'b',
    daysAgo: 3,
    contextIds: const ['work'],
    fear: 'The deadline slipping',
  ),
  _record(
    id: 'c',
    daysAgo: 0,
    contextIds: const ['work'],
    fear: 'I kept checking messages after I wanted to stop.',
  ),
];

/// A thread carried only by repeated note words — no real context behind it.
List<PressureCheckInRecord> _wordThread2() => [
  _record(id: 'w0', daysAgo: 3, fear: 'Checking messages at night'),
  _record(id: 'w1', daysAgo: 0, fear: 'Checking messages before rest'),
];

void main() {
  const engine = LowEffortCheckInEngine();

  group('Low-effort check-in engine', () {
    test('"It returned" carries the tracked thread context', () {
      final record = engine.buildRecord(
        LowEffortCheckInOption.returned,
        _workThread3(),
        now: _base,
        entryId: 'le1',
      );
      expect(record.contextIds, ['work']);
      expect(record.optionId, 'low_effort_returned');
      // No real check-in option, no notes — nothing for option-based or
      // belief engines to pick up.
      expect(record.option, isNull);
      expect(record.fear, isNull);
      expect(record.stopCostNote, isNull);
    });

    test('"It changed" also counts as a thread appearance', () {
      final record = engine.buildRecord(
        LowEffortCheckInOption.changed,
        _workThread3(),
        now: _base,
      );
      expect(record.contextIds, ['work']);
      expect(record.optionId, 'low_effort_changed');
    });

    test('"It faded" and "Not sure" never reshape the thread', () {
      for (final option in [
        LowEffortCheckInOption.faded,
        LowEffortCheckInOption.notSure,
      ]) {
        final record = engine.buildRecord(option, _workThread3(), now: _base);
        expect(
          record.contextIds,
          isEmpty,
          reason: '"${option.label}" must not add a thread occurrence',
        );
      }
    });

    test('no context is attached when the thread has no real context', () {
      final record = engine.buildRecord(
        LowEffortCheckInOption.returned,
        _wordThread2(),
        now: _base,
      );
      // "checking" is repeated language, not a PressureContext — attaching
      // it would fabricate a context that was never logged.
      expect(record.contextIds, isEmpty);
    });

    test('a returned check-in feeds future thread evidence', () {
      const threadEngine = ThreadReturnEvidenceEngine();
      final existing = _workThread3();
      final checkIn = engine.buildRecord(
        LowEffortCheckInOption.returned,
        existing,
        now: _base,
        entryId: 'le1',
      );

      final evidence = threadEngine.build([...existing, checkIn], now: _base);
      expect(evidence.occurrenceCount, 4);
      expect(evidence.entryIds, contains('le1'));
    });

    test('a faded check-in adds to the archive without faking a return', () {
      const threadEngine = ThreadReturnEvidenceEngine();
      final existing = _workThread3();
      final checkIn = engine.buildRecord(
        LowEffortCheckInOption.faded,
        existing,
        now: _base,
        entryId: 'le2',
      );

      final evidence = threadEngine.build([...existing, checkIn], now: _base);
      expect(evidence.occurrenceCount, 3);
      expect(evidence.entryIds, isNot(contains('le2')));
    });

    test('no mood labels or scores anywhere on the record', () {
      final record = engine.buildRecord(
        LowEffortCheckInOption.notSure,
        _workThread3(),
        now: _base,
      );
      final json = record.toJson().toString().toLowerCase();
      for (final banned in const ['mood', 'score', 'happy', 'sad', 'rating']) {
        expect(json, isNot(contains(banned)));
      }
    });
  });

  group('Low-effort check-in card', () {
    testWidgets('renders the copy and exactly the four options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LowEffortCheckInCard(onSelect: (_) async {})),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('low_effort_check_in_card')), findsOneWidget);
      expect(find.text('Too much to record?'), findsOneWidget);
      expect(find.text('Tap one thing instead.'), findsOneWidget);
      for (final label in const [
        'It returned',
        'It faded',
        'It changed',
        'Not sure',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(ActionChip), findsNWidgets(4));
      // No confirmation before anything is saved.
      expect(find.byKey(const Key('low_effort_confirmation')), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('tapping an option saves it, then confirms', (tester) async {
      LowEffortCheckInOption? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LowEffortCheckInCard(
              onSelect: (option) async => selected = option,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('low_effort_option_returned')));
      await tester.pumpAndSettle();

      expect(selected, LowEffortCheckInOption.returned);
      // Confirmation appears only after the save completed; the options
      // retire so the day cannot turn into repeated logging.
      expect(find.text('Saved. That is enough for today.'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
    });

    test('no banned, mood, or pressure words in any copy', () {
      final copy = [
        LowEffortCheckIn.title,
        LowEffortCheckIn.subtitle,
        LowEffortCheckIn.confirmation,
        ...LowEffortCheckInOption.values.map((o) => o.label),
      ].join(' ');
      final lower = copy.toLowerCase();
      for (final banned in const [
        'streak',
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'mood',
        'score',
      ]) {
        expect(
          lower,
          isNot(contains(banned)),
          reason: 'check-in copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_low_effort_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> seedReflections(WidgetTester tester, {int count = 3}) async {
      await tester.runAsync(() async {
        for (var i = 0; i < count; i++) {
          await AppServices.instance.journalStore.save(
            JournalEntry(
              id: 'e$i',
              createdAt: DateTime(2026, 6, 1 + i, 12),
              transcript:
                  'A long enough transcript to count as a saved reflection number $i.',
              durationSeconds: 30,
              reflection: const Reflection(
                mood: 'thoughtful',
                emotionalIntensity: 2,
                recurringThemes: ['work'],
                exactLanguagePattern: 'pattern',
                concreteObservation: 'Work pressure showed up again today.',
                repeatedSignal: 'signal',
              ),
            ),
          );
        }
      });
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      MemoryPressureCheckInStore? store,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: store,
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .byKey(const Key('one_small_recording_card'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
    }

    testWidgets('low effort check-in suppressed on capture-first record', (
      tester,
    ) async {
      await seedReflections(tester);
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(find.byKey(const Key('low_effort_check_in_card')), findsNothing);
    });

    testWidgets('tapping an option persists a real lightweight record', (
      tester,
    ) async {
      final store = MemoryPressureCheckInStore(_workThread3());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LowEffortCheckInCard(
              onSelect: (option) async {
                await store.save(
                  PressureCheckInRecord(
                    entryId: 'low_effort_${store.records.length}',
                    createdAt: DateTime(2026, 6, 12, 12),
                    optionId: option.recordOptionId,
                    contextIds: const ['work'],
                    transcript: 'low effort check-in',
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final option = find.byKey(const Key('low_effort_option_returned'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(store.records.length, 4);
      final saved = store.records.last;
      expect(saved.optionId, 'low_effort_returned');
      expect(saved.contextIds, ['work']);
      expect(find.text('Saved. That is enough for today.'), findsOneWidget);
    });

    testWidgets('no fallback without a one-small-recording starter', (
      tester,
    ) async {
      await seedReflections(tester, count: 1);
      await pumpRecordScreen(tester, store: MemoryPressureCheckInStore());

      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
      expect(find.byKey(const Key('low_effort_check_in_card')), findsNothing);
    });
  });
}
