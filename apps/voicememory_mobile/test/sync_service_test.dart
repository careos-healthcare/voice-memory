import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
Reflection _reflection() => const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: 'a',
      concreteObservation: 'b',
      repeatedSignal: 'c',
    );

void main() {
  test('mergeRemote keeps newer updatedAt', () async {
    final dir = Directory.systemTemp.createTempSync('vm_sync_');
    final store = await JournalStore.open('${dir.path}/j.json');
    await store.save(JournalEntry(
      id: '1',
      createdAt: DateTime.utc(2026, 1, 1),
      transcript: 'local older',
      durationSeconds: 1,
      reflection: _reflection(),
    ));
    await store.mergeRemote([
      JournalEntry(
        id: '1',
        createdAt: DateTime.utc(2026, 2, 1),
        transcript: 'remote newer',
        durationSeconds: 1,
        reflection: _reflection(),
        syncStatus: SyncStatus.synced,
      ),
    ]);
    final one = await store.getById('1');
    expect(one?.transcript, 'remote newer');
  });
}
