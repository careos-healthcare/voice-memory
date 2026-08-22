import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/sync/journal_conflict_resolver.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'sync_integration_test_harness.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

JournalEntry _entry({
  required String id,
  String transcript = 'baseline transcript',
  int revision = 1,
  String changeId = 'change-1',
  bool isPinned = false,
  SyncStatus syncStatus = SyncStatus.pendingUpload,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 8, 19),
    transcript: transcript,
    durationSeconds: 5,
    reflection: _reflection(),
    revision: revision,
    changeId: changeId,
    isPinned: isPinned,
    syncStatus: syncStatus,
  );
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Sync offline partition + conflict integration', () {
    late SyncIntegrationTestHarness harness;

    setUp(() async {
      harness = await SyncIntegrationTestHarness.create();
    });

    tearDown(() {
      harness.dispose();
    });

    test('queues outbox mutations while offline and drains on reconnect', () async {
      await harness.journal.save(_entry(id: 'offline-a'));
      final initial = await harness.syncNow();
      expect(initial.cloudSyncSucceeded, isTrue);

      harness.setOnline(false);
      final local = (await harness.journal.getById('offline-a'))!;
      await harness.savePendingEdit(
        local.copyWith(transcript: 'edited while offline'),
      );

      final offlineResult = await harness.syncNow();
      expect(offlineResult.cloudSyncSucceeded, isFalse);
      expect(await harness.journal.pendingSyncQueue(), hasLength(1));

      final pendingOutbox = await harness.outbox.pending();
      expect(pendingOutbox, hasLength(1));

      harness.setOnline(true);
      final recovered = await harness.syncNow();
      expect(recovered.cloudSyncSucceeded, isTrue);
      expect(await harness.outbox.pendingCount(), 0);

      final synced = await harness.journal.getById('offline-a');
      expect(synced!.transcript, 'edited while offline');
      expect(synced.syncStatus, SyncStatus.synced);
      expect(harness.syncApi.pushedSnapshots.last.single.transcript,
          'edited while offline');

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'offline-a');
    });

    test('remote-ahead concurrent edit resolves via revision OCC on reconnect', () async {
      await harness.journal.save(_entry(id: 'conflict-a', transcript: 'shared'));
      await harness.syncNow();

      final baseline = (await harness.journal.getById('conflict-a'))!;
      expect(baseline.syncStatus, SyncStatus.synced);

      harness.setOnline(false);
      await harness.savePendingEdit(
        baseline.copyWith(
          transcript: 'stale local edit',
          isPinned: true,
        ),
      );

      harness.setRemoteSnapshot([
        baseline.copyWith(
          transcript: 'authoritative remote edit',
          revision: baseline.revision + 2,
          changeId: 'remote-device-change',
          isPinned: false,
          syncStatus: SyncStatus.synced,
        ),
      ]);

      final offlineAttempt = await harness.syncNow();
      expect(offlineAttempt.cloudSyncSucceeded, isFalse);

      harness.setOnline(true);
      final merged = await harness.syncNow();
      expect(merged.cloudSyncSucceeded, isTrue);
      expect(merged.pulled, greaterThan(0));

      final after = await harness.journal.getById('conflict-a');
      expect(after!.transcript, 'authoritative remote edit');
      expect(after.revision, baseline.revision + 2);
      expect(after.changeId, 'remote-device-change');
      expect(after.isPinned, isFalse);
      expect(after.syncStatus, SyncStatus.synced);

      final relation = JournalConflictResolver.versionRelation(
        local: (await harness.journal.getById('conflict-a'))!.copyWith(
          transcript: 'stale local edit',
          revision: baseline.revision + 1,
        ),
        remote: after,
      );
      expect(relation, JournalVersionRelation.remoteAhead);

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'conflict-a');
    });

    test('local-ahead stale remote pull does not regress pending local edits', () async {
      await harness.journal.save(_entry(id: 'local-ahead'));
      await harness.syncNow();

      final synced = (await harness.journal.getById('local-ahead'))!;
      harness.setOnline(false);
      await harness.savePendingEdit(
        synced.copyWith(transcript: 'local wins because ahead'),
      );
      final localAhead = (await harness.journal.getById('local-ahead'))!;

      harness.setRemoteSnapshot([
        synced.copyWith(
          transcript: 'stale remote copy',
          revision: synced.revision - 1,
          changeId: 'stale-remote',
          syncStatus: SyncStatus.synced,
        ),
      ]);

      harness.setOnline(true);
      await harness.syncNow();

      final after = await harness.journal.getById('local-ahead');
      expect(after!.transcript, 'local wins because ahead');
      expect(after.revision, localAhead.revision);
      expect(after.syncStatus, SyncStatus.synced);

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'local-ahead');
    });

    test('field-level merge keeps equal fields when remote revision is ahead', () async {
      await harness.journal.save(
        _entry(id: 'field-merge', transcript: 'shared transcript'),
      );
      await harness.syncNow();

      final baseline = (await harness.journal.getById('field-merge'))!;
      harness.setOnline(false);
      await harness.savePendingEdit(
        baseline.copyWith(isPinned: true),
      );

      harness.setRemoteSnapshot([
        baseline.copyWith(
          transcript: 'shared transcript',
          revision: baseline.revision + 1,
          changeId: 'remote-pin-change',
          isPinned: false,
          syncStatus: SyncStatus.synced,
        ),
      ]);

      harness.setOnline(true);
      await harness.syncNow();

      final after = await harness.journal.getById('field-merge');
      expect(after!.transcript, 'shared transcript');
      expect(after.isPinned, isFalse);
      expect(after.revision, baseline.revision + 1);

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'field-merge');
    });

    test('transient push failures recover via in-process retry', () async {
      await harness.journal.save(_entry(id: 'retry-a', transcript: 'payload v1'));
      harness.failNextPushAttempts(2);

      final result = await harness.syncNow();
      expect(result.cloudSyncSucceeded, isTrue);
      expect(harness.syncApi.syncPushCalls, 3);

      final synced = await harness.journal.getById('retry-a');
      expect(synced!.syncStatus, SyncStatus.synced);
      expect(await harness.outbox.pendingCount(), 0);
      expect(harness.syncApi.pushedSnapshots, isNotEmpty);

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'retry-a');
    });

    test('remote tombstone propagates through merge and sqlite mirror', () async {
      await harness.journal.save(_entry(id: 'tomb-a'));
      await harness.syncNow();

      final live = (await harness.journal.getById('tomb-a'))!;
      final deletedAt = DateTime.utc(2026, 8, 19, 14);
      harness.setRemoteSnapshot([
        live.copyWith(
          deletedAt: deletedAt,
          revision: live.revision + 1,
          changeId: 'remote-delete',
          syncStatus: SyncStatus.synced,
        ),
      ]);

      await harness.syncNow();

      expect(await harness.journal.getById('tomb-a'), isNull);
      final tombstone = await harness.journal.getByIdIncludingTombstones('tomb-a');
      expect(tombstone!.isDeleted, isTrue);

      await harness.mirrorJournalToSqlite();
      final sqliteRow = await harness.sqliteJournalRow('tomb-a');
      expect(sqliteRow, isNotNull);
      expect(sqliteRow!['deleted_at'], isNotNull);
    });

    test('full cycle: offline edit, remote concurrent change, reconnect, mirror sync',
        () async {
      await harness.journal.save(_entry(id: 'cycle-a', transcript: 'origin'));
      await harness.syncNow();

      final origin = (await harness.journal.getById('cycle-a'))!;

      harness.setOnline(false);
      await harness.savePendingEdit(
        origin.copyWith(transcript: 'device-a offline'),
      );
      expect(await harness.engine.pendingQueue(), hasLength(1));

      final remoteWinner = origin.copyWith(
        transcript: 'device-b remote winner',
        revision: origin.revision + 3,
        changeId: 'device-b-change',
        syncStatus: SyncStatus.synced,
      );
      harness.setRemoteSnapshot([remoteWinner]);

      expect((await harness.syncNow()).cloudSyncSucceeded, isFalse);
      expect(await harness.outbox.pendingCount(), greaterThan(0));

      harness.setOnline(true);
      final result = await harness.syncNow();
      expect(result.cloudSyncSucceeded, isTrue);
      expect(await harness.outbox.pendingCount(), 0);

      final finalEntry = await harness.journal.getById('cycle-a');
      expect(finalEntry!.transcript, 'device-b remote winner');
      expect(finalEntry.syncStatus, SyncStatus.synced);

      await harness.expectSqliteMirrorMatchesJournal(entryId: 'cycle-a');
    });
  });
}
