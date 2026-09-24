import 'dart:io';

import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/core/user/user_milestone_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, DateTime createdAt) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: 'A saved moment about work.',
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Noticed a pattern',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_milestones_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('empty archive stays locked on every advanced surface', () async {
    final service = UserMilestoneService(
      prefs: prefs,
      loadEntries: () async => const [],
    );

    final snapshot = await service.load();

    expect(snapshot.journalEntryCount, 0);
    expect(snapshot.daysActive, 0);
    for (final surface in ProgressiveSurface.values) {
      expect(snapshot.isUnlocked(surface), isFalse);
      expect(snapshot.progressToward(surface), 0);
    }
  });

  test('recordAppOpen unions today with entry days', () async {
    final service = UserMilestoneService(
      prefs: prefs,
      loadEntries: () async => [
        _entry('a', DateTime.utc(2026, 9, 18)),
        _entry('b', DateTime.utc(2026, 9, 19)),
      ],
    );

    final snapshot = await service.recordAppOpen(
      now: DateTime.utc(2026, 9, 21, 8),
    );

    expect(snapshot.journalEntryCount, 2);
    expect(snapshot.daysActive, 3);
    expect(
      snapshot.activeDayKeys,
      containsAll({'2026-09-18', '2026-09-19', '2026-09-21'}),
    );
    expect(
      snapshot.isUnlocked(ProgressiveSurface.beliefShiftGraphs),
      isFalse,
    );
  });

  test('unlocks belief-shift graphs at three entries and two days', () async {
    final service = UserMilestoneService(
      prefs: prefs,
      loadEntries: () async => [
        _entry('a', DateTime.utc(2026, 9, 18)),
        _entry('b', DateTime.utc(2026, 9, 18)),
        _entry('c', DateTime.utc(2026, 9, 19)),
      ],
    );

    final snapshot = await service.load();

    expect(snapshot.isUnlocked(ProgressiveSurface.beliefShiftGraphs), isTrue);
    expect(
      snapshot.isUnlocked(ProgressiveSurface.vectorRetrievalHyperparameters),
      isFalse,
    );
    expect(snapshot.progressToward(ProgressiveSurface.beliefShiftGraphs), 1);
    expect(
      snapshot.progressToward(
        ProgressiveSurface.vectorRetrievalHyperparameters,
      ),
      closeTo((3 / 5 + 2 / 3) / 2, 0.001),
    );
  });

  test('failed entry load still records the open day', () async {
    final service = UserMilestoneService(
      prefs: prefs,
      loadEntries: () async => throw StateError('store closed'),
    );

    final snapshot = await service.recordAppOpen(
      now: DateTime.utc(2026, 9, 21),
    );

    expect(snapshot.journalEntryCount, 0);
    expect(snapshot.daysActive, 1);
    expect(snapshot.activeDayKeys, {'2026-09-21'});
  });
}
