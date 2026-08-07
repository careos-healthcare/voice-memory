import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/drift/journal_drift_migration.dart';
import 'package:voicememory_mobile/storage/journal_repository.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  test('json to drift migration verifies row-count equivalence', () async {
    expect(JournalRepositoryConfig.useDriftByDefault, isFalse);

    final dir = await Directory.systemTemp.createTemp('drift_mig_');
    final jsonStore = await JournalStore.open(
      '${dir.path}/journal.json',
      encryptAtRest: false,
    );
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final drift = InMemoryDriftJournalDatabase();

    await jsonStore.save(
      JournalEntry(
        id: 'row-1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'hello',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );

    final migration = JsonToDriftJournalMigration(
      jsonStore: jsonStore,
      driftDb: drift,
      prefs: prefs,
    );
    final state = await migration.runIfNeeded(
      dbPath: '${dir.path}/journal.db',
      encryptionKey: List<int>.filled(32, 7),
    );
    expect(state.status, 'completed');
    expect(state.rowCount, 1);
    expect(await drift.countEntries(), 1);
  });
}
