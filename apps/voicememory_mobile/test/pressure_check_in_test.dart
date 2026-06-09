import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_service.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_context.dart';
import 'package:voicememory_mobile/screens/pressure_check_in_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_quick_save_success.dart';

typedef _Stores = ({
  JournalStore journal,
  PressureCheckInStore store,
  MobilePrefsStore prefs,
});

Future<_Stores> _openStores(String stamp) async {
  final dir = Directory('test/tmp/pressure_check_in');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final journalPath = '${dir.path}/journal_$stamp.json';
  final prefsPath = '${dir.path}/prefs_$stamp.json';
  for (final path in [journalPath, prefsPath]) {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
  final journal = await JournalStore.open(journalPath);
  final prefs = await MobilePrefsStore.open(prefsPath);
  return (
    journal: journal,
    store: PressureCheckInStore.forPrefs(prefs),
    prefs: prefs,
  );
}

PressureCheckInService _service(_Stores stores) => PressureCheckInService(
      journalStore: stores.journal,
      store: stores.store,
    );

void main() {
  group('PressureCheckInService quick save (task 1)', () {
    test('uses the pressure_check_in first25 source', () {
      expect(PressureCheckInService.first25Source, 'pressure_check_in');
    });

    test('selected option can save without typing a note', () async {
      final stores = await _openStores('quick_no_note');
      final service = _service(stores);

      final result = await service.save(
        option: PressureCheckInOption.couldNotStop,
        now: DateTime(2026, 6, 1),
      );

      expect(result.record.optionId, 'could_not_stop');
      expect(result.record.stopCostNote, isNull);
      expect(result.record.fear, isNull);
      expect(result.record.choseToStop, isFalse);

      final entries = await stores.journal.loadAll();
      expect(entries.length, 1);
      final records = await stores.store.loadAll();
      expect(records.length, 1);
      expect(records.first.optionId, 'could_not_stop');
    });

    test('saved journal entry still has evidence-grade transcript', () async {
      final stores = await _openStores('evidence_grade');
      final service = _service(stores);

      await service.save(
        option: PressureCheckInOption.hadToProveEnough,
        now: DateTime(2026, 6, 1),
      );

      final eligible = await stores.journal.loadEligible();
      expect(eligible.length, 1);
      final entry = eligible.first;
      expect(entry.transcript.trim(), isNotEmpty);
      expect(entry.transcript.startsWith('[draft]'), isFalse);
      expect(
        entry.transcript,
        contains(PressureCheckInOption.hadToProveEnough.momentPhrase),
      );
      expect(entry.transcript.toLowerCase(), isNot(contains('voicememory')));
    });

    testWidgets('payoff still appears after quick save', (tester) async {
      await tester.runAsync(() async {
        final dir = Directory('test/tmp/pressure_check_in');
        if (!await dir.exists()) await dir.create(recursive: true);
        await AppServices.resetForTest(
          journalPath: '${dir.path}/payoff_journal.json',
          prefsPath: '${dir.path}/payoff_prefs.json',
          skipRevenueCat: true,
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: PressureCheckInScreen()),
      );
      await tester.pump();

      await tester.tap(
        find.text("I couldn't stop even though I wanted to"),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pressure_quick_save_cta')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pressure_quick_save_success')),
        findsOneWidget,
      );
      expect(find.text(PressureQuickSaveSuccess.message), findsOneWidget);
      expect(
        find.byKey(const Key('prove_enough_post_record_payoff')),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Pressure context capture (task 3)', () {
    testWidgets('context chips render after selecting an option',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: PressureCheckInScreen()),
      );
      await tester.pump();

      // No context chips until an option is chosen.
      expect(find.byType(FilterChip), findsNothing);

      await tester.tap(find.text('I felt guilty about resting'));
      await tester.pump();

      expect(find.byType(FilterChip), findsNWidgets(PressureContext.values.length));
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Before sleep'), findsOneWidget);
      expect(find.text('After praise/criticism'), findsOneWidget);
      expect(find.text('Deadline'), findsOneWidget);
    });

    test('selected context saves with the entry', () async {
      final stores = await _openStores('context_saves');
      final service = _service(stores);

      final result = await service.save(
        option: PressureCheckInOption.keptGoingToFeelProductive,
        contexts: const [PressureContext.work, PressureContext.deadline],
        now: DateTime(2026, 6, 1),
      );

      expect(result.record.contextIds, containsAll(['work', 'deadline']));
      expect(result.entry.transcript.toLowerCase(), contains('work'));
      expect(result.entry.transcript.toLowerCase(), contains('deadline'));

      final reloaded = (await stores.store.loadAll()).first;
      expect(reloaded.contextIds, containsAll(['work', 'deadline']));
      expect(reloaded.contexts, contains(PressureContext.work));
    });

    test('fear field saves with the entry', () async {
      final stores = await _openStores('fear_saves');
      final service = _service(stores);

      final result = await service.save(
        option: PressureCheckInOption.didMoreToNotFeelBehind,
        fear: 'I would fall behind everyone else',
        now: DateTime(2026, 6, 1),
      );

      expect(result.record.fear, 'I would fall behind everyone else');
      expect(
        result.entry.transcript,
        contains('I would fall behind everyone else'),
      );

      final reloaded = (await stores.store.loadAll()).first;
      expect(reloaded.fear, 'I would fall behind everyone else');
    });

    test('no context still saves successfully', () async {
      final stores = await _openStores('no_context');
      final service = _service(stores);

      final result = await service.save(
        option: PressureCheckInOption.didMoreToNotFeelBehind,
        contexts: const [],
        now: DateTime(2026, 6, 1),
      );

      expect(result.record.contextIds, isEmpty);
      final records = await stores.store.loadAll();
      expect(records.length, 1);
      final entries = await stores.journal.loadEligible();
      expect(entries.length, 1);
    });
  });
}
