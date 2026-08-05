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

  test('new entries are stamped with the active owner key', () async {
    store.setActiveOwnerKey('user-a');
    await store.save(sample(id: 'a'));

    final saved = await store.getById('a');
    expect(saved?.ownerKey, 'user-a');
  });

  test('re-saving an existing entry never overwrites its owner key', () async {
    store.setActiveOwnerKey('user-a');
    await store.save(sample(id: 'a'));

    store.setActiveOwnerKey('user-b');
    await store.update((await store.getById('a'))!);

    final saved = await store.getById('a');
    expect(saved?.ownerKey, 'user-a');
  });

  test('entries created while signed out stay unowned', () async {
    store.setActiveOwnerKey(null);
    await store.save(sample(id: 'a'));

    final saved = await store.getById('a');
    expect(saved?.ownerKey, isNull);
  });

  test('markSynced preserves the owner key', () async {
    store.setActiveOwnerKey('user-a');
    await store.save(sample(id: 'a'));

    await store.markSynced('a');

    final saved = await store.getById('a');
    expect(saved?.ownerKey, 'user-a');
    expect(saved?.syncStatus, SyncStatus.synced);
  });

  test('mergeRemote preserves the local owner key for existing entries', () async {
    store.setActiveOwnerKey('user-a');
    await store.save(sample(id: 'a'));

    await store.mergeRemote([
      JournalEntry(
        id: 'a',
        createdAt: DateTime.utc(2026, 1, 5),
        transcript: 'Updated remotely',
        durationSeconds: 10,
        reflection: sampleReflection(),
        syncStatus: SyncStatus.synced,
      ),
    ]);

    final saved = await store.getById('a');
    expect(saved?.transcript, 'Updated remotely');
    expect(saved?.ownerKey, 'user-a');
  });
}
