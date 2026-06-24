import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDir;
  late JournalStore store;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_journal_');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    store = await JournalStore.open(
      '${tempDir.path}/entries.json',
      keyStore: keyStore,
    );
  });

  Reflection sampleReflection() => const Reflection(
    mood: 'calm',
    emotionalIntensity: 4,
    recurringThemes: ['family'],
    exactLanguagePattern: 'I need quiet',
    concreteObservation: 'You asked for quiet time.',
    repeatedSignal: 'Quiet mentioned twice.',
  );

  JournalEntry sample({required String id, DateTime? createdAt}) {
    return JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 2),
      transcript: 'Test $id',
      durationSeconds: 10,
      reflection: sampleReflection(),
      syncStatus: SyncStatus.localOnly,
    );
  }

  test('save list delete export', () async {
    expect(await store.loadAll(), isEmpty);

    await store.save(sample(id: 'a'));
    await store.save(sample(id: 'b', createdAt: DateTime.utc(2026, 1, 3)));

    final list = await store.loadAll();
    expect(list.length, 2);
    expect(list.first.id, 'b');

    final found = await store.getById('a');
    expect(found?.transcript, 'Test a');

    await store.delete('a');
    expect((await store.loadAll()).length, 1);

    final json = await store.exportJson();
    expect(json, contains('"id": "b"'));
    expect(json, isNot(contains('"id": "a"')));
  });
}
