import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/sync/journal_conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

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
  String transcript = 'hello',
  int revision = 1,
  String changeId = 'change-1',
  bool isPinned = false,
  DateTime? deletedAt,
  SyncStatus syncStatus = SyncStatus.synced,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026),
    transcript: transcript,
    durationSeconds: 5,
    reflection: _reflection(),
    revision: revision,
    changeId: changeId,
    isPinned: isPinned,
    deletedAt: deletedAt,
    syncStatus: syncStatus,
  );
}

void main() {
  group('JournalConflictResolver.versionRelation', () {
    test('uses revision integers only', () {
      final local = _entry(id: 'a', revision: 3);
      final remote = _entry(id: 'a', revision: 5);

      expect(
        JournalConflictResolver.versionRelation(local: local, remote: remote),
        JournalVersionRelation.remoteAhead,
      );
      expect(
        JournalConflictResolver.versionRelation(local: remote, remote: local),
        JournalVersionRelation.localAhead,
      );
      expect(
        JournalConflictResolver.versionRelation(
          local: _entry(id: 'a', revision: 2),
          remote: _entry(id: 'a', revision: 2),
        ),
        JournalVersionRelation.sameRevision,
      );
    });
  });

  group('JournalConflictResolver.resolve', () {
    test('local ahead keeps local row unchanged', () {
      final local = _entry(
        id: 'a',
        transcript: 'local edit',
        revision: 4,
        changeId: 'local-change',
      );
      final remote = _entry(
        id: 'a',
        transcript: 'remote edit',
        revision: 3,
        changeId: 'remote-change',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.shouldPersist, isFalse);
      expect(result.kind, JournalConflictResolutionKind.localWinner);
      expect(result.entry.transcript, 'local edit');
    });

    test('remote ahead preserves remote revision and changeId', () {
      final local = _entry(
        id: 'a',
        transcript: 'stale local',
        revision: 2,
        changeId: 'local-change',
      );
      final remote = _entry(
        id: 'a',
        transcript: 'authoritative remote',
        revision: 3,
        changeId: 'remote-change',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.shouldPersist, isTrue);
      expect(result.kind, JournalConflictResolutionKind.fieldMerged);
      expect(result.entry.transcript, 'authoritative remote');
      expect(result.entry.revision, 3);
      expect(result.entry.changeId, 'remote-change');
      expect(result.entry.syncStatus, SyncStatus.synced);
    });

    test('remote ahead merges non-conflicting equal fields', () {
      final local = _entry(
        id: 'a',
        transcript: 'shared transcript',
        revision: 2,
        isPinned: true,
        changeId: 'local-change',
      );
      final remote = _entry(
        id: 'a',
        transcript: 'shared transcript',
        revision: 3,
        isPinned: false,
        changeId: 'remote-change',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.entry.transcript, 'shared transcript');
      expect(result.entry.isPinned, isFalse);
      expect(result.entry.revision, 3);
    });

    test('same revision collision uses changeId tie-breaker, not updatedAt', () {
      final ts = DateTime.utc(2026, 3);
      final local = _entry(id: 'a', revision: 5, changeId: 'zzz-winner').copyWith(
        updatedAt: ts.add(const Duration(hours: 1)),
        transcript: 'local transcript',
      );
      final remote = _entry(id: 'a', revision: 5, changeId: 'aaa-loser').copyWith(
        updatedAt: ts,
        transcript: 'remote transcript',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.shouldPersist, isFalse);
      expect(result.entry.transcript, 'local transcript');
      expect(result.collisions, isNotEmpty);
    });

    test('same revision remote wins when changeId is higher', () {
      final local = _entry(id: 'a', revision: 5, changeId: 'aaa-loser').copyWith(
        transcript: 'local transcript',
      );
      final remote = _entry(id: 'a', revision: 5, changeId: 'zzz-winner').copyWith(
        transcript: 'remote transcript',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.shouldPersist, isTrue);
      expect(result.entry.transcript, 'remote transcript');
      expect(result.entry.changeId, 'zzz-winner');
    });

    test('markConflict policy flags review and sets conflict status', () {
      final local = _entry(id: 'a', revision: 2, changeId: 'local-change').copyWith(
        transcript: 'local transcript',
        isPinned: true,
      );
      final remote = _entry(id: 'a', revision: 2, changeId: 'remote-change').copyWith(
        transcript: 'remote transcript',
        isPinned: false,
      );

      final result = JournalConflictResolver.resolve(
        local: local,
        remote: remote,
        policy: JournalCollisionPolicy.markConflict,
        changeIdGenerator: () => 'merged-change',
      );

      expect(result.requiresReview, isTrue);
      expect(result.entry.syncStatus, SyncStatus.conflict);
      expect(result.entry.changeId, 'merged-change');
      expect(result.collisions.map((c) => c.field), contains('transcript'));
    });

    test('remote tombstone with higher revision wins over live local copy', () {
      final local = _entry(id: 'a', revision: 2);
      final deletedAt = DateTime.utc(2026, 6);
      final remote = local.copyWith(
        deletedAt: deletedAt,
        revision: 3,
        changeId: 'remote-delete',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.entry.isDeleted, isTrue);
      expect(result.entry.deletedAt, deletedAt);
    });

    test('stale non-deleted remote does not resurrect local tombstone', () {
      final deletedAt = DateTime.utc(2026, 6);
      final local = _entry(id: 'a', revision: 3, changeId: 'local-tomb').copyWith(
        deletedAt: deletedAt,
      );
      final remote = _entry(id: 'a', revision: 2, changeId: 'stale-live').copyWith(
        deletedAt: null,
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.shouldPersist, isFalse);
      expect(result.entry.isDeleted, isTrue);
    });

    test('preserves localAudioPath from local copy', () {
      final local = _entry(id: 'a', revision: 2).copyWith(
        localAudioPath: '/tmp/local.m4a',
      );
      final remote = _entry(id: 'a', revision: 3, changeId: 'remote-change').copyWith(
        transcript: 'remote transcript',
      );

      final result = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(result.entry.localAudioPath, '/tmp/local.m4a');
      expect(result.entry.transcript, 'remote transcript');
    });

    test('identical entries produce no-op merge', () {
      final entry = _entry(id: 'a', revision: 2, changeId: 'same');
      final result = JournalConflictResolver.resolve(local: entry, remote: entry);

      expect(result.kind, JournalConflictResolutionKind.noConflict);
      expect(result.shouldPersist, isTrue);
    });
  });
}
