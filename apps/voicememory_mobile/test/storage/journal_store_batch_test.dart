import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_entry_decoder.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

JournalEntry _entry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 1, 1),
  transcript: 'text $id',
  durationSeconds: 1,
  reflection: _reflection(),
  updatedAt: DateTime.utc(2026, 1, 2),
  revision: 1,
  changeId: 'change-$id',
);

void main() {
  test('markSyncedBatch with 200 ids performs one persist write', () async {
    JournalStoreWriteInstrumentation.reset();
    final dir = await Directory.systemTemp.createTemp('journal_batch_');
    final store = await JournalStore.open(
      '${dir.path}/journal.json',
      encryptAtRest: false,
    );

    final entries = List.generate(200, (i) => _entry('e-$i'));
    await store.replaceAll(entries);

    JournalStoreWriteInstrumentation.reset();
    await store.markSyncedBatch(entries.map((e) => e.id).toSet());

    expect(JournalStoreWriteInstrumentation.persistCount, 1);
    final first = await store.getByIdIncludingTombstones('e-0');
    expect(first?.syncStatus, SyncStatus.synced);
  });

  test('decoder quarantines invalid record without aborting valid ones', () {
    final quarantined = <JournalDecodeQuarantined>[];
    final accepted = JournalEntryDecoder.decodeList([
      _entry('good').toJson(),
      {'id': '', 'createdAt': 'not-a-date'},
    ], quarantineOut: quarantined);
    expect(accepted, hasLength(1));
    expect(accepted.single.id, 'good');
    expect(quarantined, isNotEmpty);
  });
}
