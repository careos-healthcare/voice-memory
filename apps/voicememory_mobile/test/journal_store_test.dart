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

  test(
    'mergeRemote preserves the local owner key for existing entries',
    () async {
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
    },
  );

  group('tombstone lifecycle (Objective 2 — sync versioning and deletion)', () {
    test('local delete creates a tombstone, not a hard removal', () async {
      await store.save(sample(id: 'a'));

      await store.delete('a');

      expect(await store.getById('a'), isNull);
      final withTombstones = await store.loadAllIncludingTombstones();
      final tombstone = withTombstones.firstWhere((e) => e.id == 'a');
      expect(tombstone.isDeleted, isTrue);
      expect(tombstone.deletedAt, isNotNull);
      // Content is retained, not forgotten.
      expect(tombstone.transcript, 'Test a');
    });

    test('a tombstoned entry disappears from every normal query', () async {
      await store.save(sample(id: 'a'));
      await store.save(sample(id: 'b'));
      await store.delete('a');

      expect(
        await store.loadAll(),
        everyElement(isA<JournalEntry>().having((e) => e.id, 'id', isNot('a'))),
      );
      expect((await store.loadEligible()).any((e) => e.id == 'a'), isFalse);
      expect(store.loadAllSync().any((e) => e.id == 'a'), isFalse);
    });

    test(
      'deleting queues the tombstone for upload so it can propagate',
      () async {
        await store.save(sample(id: 'a'));
        await store.markSynced('a');

        await store.delete('a');

        final pending = await store.pendingTombstones();
        expect(pending.map((e) => e.id), contains('a'));
      },
    );

    test(
      'a local tombstone is never resurrected by an older remote copy',
      () async {
        await store.save(sample(id: 'a'));
        await store.delete('a');
        final tombstone = (await store.loadAllIncludingTombstones()).firstWhere(
          (e) => e.id == 'a',
        );

        // Remote sends back a stale, lower-revision copy of the same entry
        // (e.g. another device that pulled before the delete happened).
        await store.mergeRemote([
          sample(id: 'a').copyWith(revision: tombstone.revision - 1),
        ]);

        expect(await store.getById('a'), isNull);
        final stillDeleted = (await store.loadAllIncludingTombstones())
            .firstWhere((e) => e.id == 'a');
        expect(stillDeleted.isDeleted, isTrue);
      },
    );

    test(
      'a winning remote tombstone deletes the entry locally (remote delete propagation)',
      () async {
        await store.save(sample(id: 'a'));

        final remoteTombstone = sample(
          id: 'a',
        ).copyWith(revision: 5, deletedAt: DateTime.utc(2026, 1, 10));

        await store.mergeRemote([remoteTombstone]);

        expect(await store.getById('a'), isNull);
        final stored = (await store.loadAllIncludingTombstones()).firstWhere(
          (e) => e.id == 'a',
        );
        expect(stored.isDeleted, isTrue);
      },
    );

    test(
      'compactTombstones only purges acknowledged, retention-expired tombstones',
      () async {
        await store.save(sample(id: 'a'));
        await store.save(sample(id: 'b'));
        await store.save(sample(id: 'c'));

        await store.delete('a'); // pending upload — must not be purged yet.
        await store.delete('b'); // will be acknowledged, but too recent.
        await store.delete('c'); // will be acknowledged and old enough.
        await store.markSynced('b');
        await store.markSynced('c');

        // Backdate c's tombstone as if it was deleted long ago.
        final cEntry = (await store.loadAllIncludingTombstones()).firstWhere(
          (e) => e.id == 'c',
        );
        await store.save(cEntry.copyWith(deletedAt: DateTime.utc(2020, 1, 1)));

        final purged = await store.compactTombstones(
          retention: const Duration(days: 30),
          now: () => DateTime.utc(2026, 1, 1),
        );

        expect(purged, 1);
        final remainingIds = (await store.loadAllIncludingTombstones())
            .map((e) => e.id)
            .toSet();
        expect(remainingIds, {'a', 'b'});
        expect(remainingIds.contains('c'), isFalse);
      },
    );

    test(
      'save() never drops unrelated tombstones when persisting another entry',
      () async {
        await store.save(sample(id: 'a'));
        await store.save(sample(id: 'b'));
        await store.delete('a');

        // Saving/updating an unrelated entry must not silently erase a's
        // tombstone from disk.
        await store.save(
          (await store.getById('b'))!.copyWith(transcript: 'edited'),
        );

        final withTombstones = await store.loadAllIncludingTombstones();
        expect(withTombstones.map((e) => e.id).toSet(), {'a', 'b'});
        expect(withTombstones.firstWhere((e) => e.id == 'a').isDeleted, isTrue);
      },
    );
  });
}
