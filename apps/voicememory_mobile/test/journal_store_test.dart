import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDir;
  late JournalStore store;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;

  setUp(() async {
    ProductAnalytics.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('vm_journal_');
    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    store = await JournalStore.open(
      '${tempDir.path}/entries.json',
      ownerArchiveId: 'local',
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

  // Activation analytics used to be emitted from inside this store, which put
  // reporting in the persistence layer and fired on any write, including a
  // restore or a migration. V1 moved it to the capture path, where
  // `first_capture_saved` is reported against a real capture and is covered by
  // capture_performance_test.
  //
  // What remains true here is the layering rule, and it is asserted rather than
  // assumed: persisting a moment reports nothing by itself. Written as a
  // positive check on the whole event list, so it cannot pass merely because a
  // single named event disappeared.
  test('saving a moment emits no analytics from the storage layer', () async {
    final first = sample(id: 'first');
    await store.save(first);
    await store.save(first);
    await store.save(sample(id: 'second'));
    await store.save(
      JournalEntry(
        id: 'typed',
        createdAt: DateTime.utc(2026, 1, 2),
        transcript: 'Typed thought',
        durationSeconds: 0,
        reflection: sampleReflection(),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      ProductAnalytics.eventsForTest.map((event) => event.event),
      isEmpty,
      reason:
          'The journal store must not report. Capture-path events belong to '
          'the capture pipeline, which knows a save came from a real capture.',
    );
  });

  test('watchAll emits immutable snapshots after committed writes', () async {
    final snapshots = <List<JournalEntry>>[];
    final subscription = store.watchAll().listen(snapshots.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await store.save(sample(id: 'a'));
    await store.delete('a');
    await Future<void>.delayed(Duration.zero);

    expect(snapshots.map((items) => items.length), [0, 1, 0]);
    expect(
      () => snapshots[1].add(sample(id: 'mutate')),
      throwsUnsupportedError,
    );
  });

  test(
    'post-persist materialization failure does not fail journal save',
    () async {
      store.configurePostPersistHook(
        (_) => Future<void>.error(StateError('graph')),
      );

      await expectLater(store.save(sample(id: 'saved')), completes);

      expect((await store.getById('saved'))?.transcript, 'Test saved');
    },
  );

  test(
    'local writes increment vector metadata and mark edits pending',
    () async {
      var now = DateTime.utc(2026, 7, 26, 10);
      store = await JournalStore.open(
        '${tempDir.path}/revision_entries.json',
        ownerArchiveId: 'local',
        keyStore: keyStore,
        syncDeviceIdProvider: () async => 'device-a',
        clock: () => now,
      );

      await store.save(sample(id: 'revision'));
      final first = (await store.getById('revision'))!;
      expect(first.syncMetadata?.sourceDeviceId, 'device-a');
      expect(first.syncMetadata?.vectorClock, const {'device-a': 1});
      expect(first.syncStatus, SyncStatus.localOnly);

      await store.markSynced('revision');
      now = DateTime.utc(2026, 7, 26, 11);
      await store.save(
        (await store.getById('revision'))!.copyWith(captureContextTag: 'work'),
      );
      final edited = (await store.getById('revision'))!;
      expect(edited.syncStatus, SyncStatus.pendingUpload);
      expect(edited.syncMetadata?.updatedAt, now);
      expect(edited.syncMetadata?.vectorClock, const {'device-a': 2});
    },
  );
}
