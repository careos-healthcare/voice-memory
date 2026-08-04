import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_ownership_decision_service.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_scope_paths.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/journal/migration/saved_moment_legacy_adapter.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

/// Adversarial cross-account isolation. Every case here answers the same
/// question from a different angle: can Account B ever observe, upload, alter
/// or destroy content it does not own?
void main() {
  late Directory root;
  late InMemorySecureStorageService secure;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vm_isolation_');
    secure = InMemorySecureStorageService();
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<JournalStore> open(LocalArchiveIdentity identity) => JournalStore.open(
    ArchiveScopePaths.journalPath(basePath: root.path, identity: identity),
    ownerArchiveId: identity.archiveId,
    encryptAtRest: false,
  );

  ArchiveOwnershipDecisionService service() =>
      ArchiveOwnershipDecisionService(secure: secure, openStore: open);

  group('storage boundary', () {
    test('two accounts never share a journal file', () async {
      final a = await open(_accountA);
      final b = await open(_accountB);
      await a.save(_entry('a-1'));
      await b.save(_entry('b-1'));

      expect(a.file.path, isNot(b.file.path));
      expect((await a.loadAll()).map((entry) => entry.id), ['a-1']);
      expect((await b.loadAll()).map((entry) => entry.id), ['b-1']);
    });

    test(
      'a foreign row already on disk is invisible to every read path',
      () async {
        final path = ArchiveScopePaths.journalPath(
          basePath: root.path,
          identity: _accountB,
        );
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString(
          jsonEncode([
            _entry('a-secret', owner: _accountA.archiveId).toJson(),
            _entry('b-own', owner: _accountB.archiveId).toJson(),
          ]),
        );

        final b = await open(_accountB);

        expect((await b.loadAll()).map((entry) => entry.id), ['b-own']);
        expect(
          (await b.loadAll(includeDeleted: true)).map((entry) => entry.id),
          ['b-own'],
        );
        expect((await b.loadEligible()).map((entry) => entry.id), ['b-own']);
        expect(
          (await b.pendingSyncQueue()).map((entry) => entry.id),
          isNot(contains('a-secret')),
        );
        expect(await b.getById('a-secret'), isNull);
        expect(await b.exportJson(), isNot(contains('a-secret')));
        expect(await b.reflectionCount(), 1);
      },
    );

    test('opening a foreign file never re-owns its rows', () async {
      final payload = {
        'id': 'a-secret',
        'ownerArchiveId': _accountA.archiveId,
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'transcript': 'account a words',
      };

      final migrated = SavedMomentLegacyAdapter.migrate(
        payload,
        ownerArchiveId: _accountB.archiveId,
        migratedAt: DateTime.utc(2026, 2),
      );

      expect(migrated['ownerArchiveId'], _accountA.archiveId);
    });

    test('a genuinely ownerless legacy row is adopted, once', () {
      final migrated = SavedMomentLegacyAdapter.migrate(
        {
          'id': 'legacy-1',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'transcript': 'older words',
        },
        ownerArchiveId: _legacy.archiveId,
        migratedAt: DateTime.utc(2026, 2),
      );

      expect(migrated['ownerArchiveId'], _legacy.archiveId);
      expect(
        SavedMomentLegacyAdapter.belongsToAnotherArchive(
          migrated,
          ownerArchiveId: _accountB.archiveId,
        ),
        isTrue,
      );
    });

    test('B cannot write, alter or delete an entry owned by A', () async {
      final b = await open(_accountB);

      expect(
        () => b.save(_entry('a-1', owner: _accountA.archiveId)),
        throwsStateError,
      );

      final path = ArchiveScopePaths.journalPath(
        basePath: root.path,
        identity: _accountB,
      );
      await File(path).parent.create(recursive: true);
      await File(path).writeAsString(
        jsonEncode([_entry('a-1', owner: _accountA.archiveId).toJson()]),
      );
      final reopened = await open(_accountB);
      await reopened.delete('a-1');
      await reopened.save(_entry('b-1'));

      final onDisk = jsonDecode(await File(path).readAsString()) as List;
      final aRow = onDisk.singleWhere((row) => row['id'] == 'a-1');
      expect(aRow['ownerArchiveId'], _accountA.archiveId);
      expect(aRow['deletedAt'], isNull);
    });

    test('the same client entry ID cannot cross owners', () async {
      final a = await open(_accountA);
      final b = await open(_accountB);
      await a.save(_entry('shared-id'));
      await b.save(_entry('shared-id'));

      final fromA = await a.getById('shared-id');
      final fromB = await b.getById('shared-id');

      expect(fromA!.ownerArchiveId, _accountA.archiveId);
      expect(fromB!.ownerArchiveId, _accountB.archiveId);
      expect(a.file.path, isNot(b.file.path));
    });

    test('a restore cannot import another account ownership', () async {
      final b = await open(_accountB);
      await b.replaceAll([_entry('restored', owner: _accountA.archiveId)]);

      final restored = await b.getById('restored');
      expect(restored!.ownerArchiveId, _accountB.archiveId);
    });

    test('deleting under B leaves A untouched', () async {
      final a = await open(_accountA);
      final b = await open(_accountB);
      await a.save(_entry('a-1'));
      await b.save(_entry('b-1'));

      await b.delete('b-1');
      await b.clearAll();

      expect((await a.loadAll()).map((entry) => entry.id), ['a-1']);
    });
  });

  group('ownership decision', () {
    test('guest content is never claimed automatically', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));

      final pending = await service().pendingDecision(
        account: _accountB,
        candidate: _guest,
      );

      expect(pending, isNotNull);
      expect(pending!.momentCount, 1);
      expect(pending.sourceArchiveId, _guest.archiveId);
      expect(
        UnclaimedArchiveSummary.prompt,
        'This device contains private saved moments. They have not been '
        'added to this account.',
      );
      expect((await open(_accountB)).loadAllSync(), isEmpty);
    });

    test('Account A content is never offered to Account B', () async {
      final a = await open(_accountA);
      await a.save(_entry('a-1'));

      expect(ArchiveOwnershipDecisionService.isClaimable(_accountA), isFalse);
      expect(
        await service().pendingDecision(
          account: _accountB,
          candidate: _accountA,
        ),
        isNull,
      );
      expect(
        () => service().moveToAccount(
          account: _accountB,
          candidate: _accountA,
          confirmed: true,
        ),
        throwsStateError,
      );
    });

    test('keep separate leaves B with zero guest entries', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));

      await service().keepSeparate(_guest.archiveId);

      expect(
        await service().pendingDecision(account: _accountB, candidate: _guest),
        isNull,
      );
      expect((await open(_accountB)).loadAllSync(), isEmpty);
      expect((await open(_guest)).loadAllSync(), hasLength(1));
    });

    test('move requires explicit confirmation', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));

      expect(
        () => service().moveToAccount(
          account: _accountB,
          candidate: _guest,
          confirmed: false,
        ),
        throwsStateError,
      );
      expect((await open(_accountB)).loadAllSync(), isEmpty);
    });

    test('move preserves dates and evidence, and empties the source', () async {
      final guest = await open(_guest);
      final captured = DateTime.utc(2025, 4, 3, 8, 30);
      await guest.save(_entry('guest-1', createdAt: captured));

      final result = await service().moveToAccount(
        account: _accountB,
        candidate: _guest,
        confirmed: true,
      );

      expect(result.committed, isTrue);
      expect(result.migratedCount, 1);
      final moved = await (await open(_accountB)).getById('guest-1');
      expect(moved, isNotNull);
      expect(moved!.createdAt, captured);
      expect(moved.localAudioVaultRef, 'vault-guest-1');
      expect(moved.ownerArchiveId, _accountB.archiveId);
      expect((await open(_guest)).loadAllSync(), isEmpty);
    });

    test('a repeated move produces no duplicates', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));
      await service().moveToAccount(
        account: _accountB,
        candidate: _guest,
        confirmed: true,
      );

      final replay = await service().moveToAccount(
        account: _accountB,
        candidate: _guest,
        confirmed: true,
      );

      expect(replay.migratedCount, 0);
      expect((await open(_accountB)).loadAllSync(), hasLength(1));
    });

    test('an interrupted move resumes without duplicating', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));
      await guest.save(_entry('guest-2'));
      final target = await open(_accountB);
      await target.save(_entry('guest-1'));
      await secure.write(
        'archive_ownership_migration_v1',
        jsonEncode(
          const ArchiveMigrationRecord(
            sourceArchiveId: 'guest-archive',
            targetArchiveId: 'account-b',
            state: ArchiveMigrationState.copying,
            migratedEntryIds: ['guest-1'],
          ).toJson(),
        ),
      );

      expect(await service().pendingMigration(), isNotNull);
      expect(await service().mayResumeSync(_accountB), isFalse);

      final result = await service().moveToAccount(
        account: _accountB,
        candidate: _guest,
        confirmed: true,
      );

      expect(result.migratedCount, 1);
      expect(result.alreadyPresentCount, 1);
      expect((await open(_accountB)).loadAllSync(), hasLength(2));
      expect(await service().pendingMigration(), isNull);
      expect(await service().mayResumeSync(_accountB), isTrue);
    });

    test('export and delete work without adopting the content', () async {
      final guest = await open(_guest);
      await guest.save(_entry('guest-1'));

      final exported = await service().exportUnclaimed(_guest);
      expect(exported, contains('guest-1'));
      expect((await open(_accountB)).loadAllSync(), isEmpty);

      await service().deleteUnclaimed(_guest);
      expect((await open(_guest)).loadAllSync(), isEmpty);
      expect(
        await service().decisionFor(_guest.archiveId),
        ArchiveOwnershipDecision.deleted,
      );
    });
  });

  group('ownership state', () {
    test('unresolved ownership fails closed for sync and render', () {
      const awaiting = LocalArchiveIdentity(
        archiveId: 'legacy-archive',
        ownerKind: LocalArchiveOwnerKind.legacyUnclaimed,
        ownershipState: LocalArchiveOwnershipState.awaitingDecision,
      );
      const migrating = LocalArchiveIdentity(
        archiveId: 'account-b',
        ownerKind: LocalArchiveOwnerKind.authenticated,
        authenticatedSubjectId: 'subject-b',
        ownershipState: LocalArchiveOwnershipState.migrating,
      );
      const locked = LocalArchiveIdentity(
        archiveId: 'guest-archive',
        ownerKind: LocalArchiveOwnerKind.guest,
        ownershipState: LocalArchiveOwnershipState.locked,
      );

      expect(awaiting.maySync, isFalse);
      expect(migrating.maySync, isFalse);
      expect(locked.maySync, isFalse);
      expect(locked.mayRender, isFalse);
      expect(_guest.maySync, isFalse);
      expect(_accountB.maySync, isTrue);
    });

    test(
      'a resolved identity survives a restart under the same owner',
      () async {
        final store = LocalArchiveIdentityStore(secure);
        final first = await store.resolve(
          authenticatedSubjectId: 'subject-b',
          legacyOwnerlessArchiveExists: false,
        );
        final second = await store.resolve(
          authenticatedSubjectId: 'subject-b',
          legacyOwnerlessArchiveExists: false,
        );
        final other = await store.resolve(
          authenticatedSubjectId: 'subject-a',
          legacyOwnerlessArchiveExists: false,
        );

        expect(second.archiveId, first.archiveId);
        expect(other.archiveId, isNot(first.archiveId));
        expect(other.authenticatedSubjectId, 'subject-a');
      },
    );

    test('legacy ownerless data resolves to legacyUnclaimed', () async {
      final store = LocalArchiveIdentityStore(secure);
      final identity = await store.resolve(
        authenticatedSubjectId: null,
        legacyOwnerlessArchiveExists: true,
      );

      expect(identity.ownerKind, LocalArchiveOwnerKind.legacyUnclaimed);
      expect(
        identity.ownershipState,
        LocalArchiveOwnershipState.awaitingDecision,
      );
      expect(identity.maySync, isFalse);
      expect(ArchiveOwnershipDecisionService.isClaimable(identity), isTrue);
    });
  });
}

const _accountA = LocalArchiveIdentity(
  archiveId: 'account-a',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-a',
  ownershipState: LocalArchiveOwnershipState.active,
);

const _accountB = LocalArchiveIdentity(
  archiveId: 'account-b',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-b',
  ownershipState: LocalArchiveOwnershipState.active,
);

const _guest = LocalArchiveIdentity(
  archiveId: 'guest-archive',
  ownerKind: LocalArchiveOwnerKind.guest,
  ownershipState: LocalArchiveOwnershipState.active,
);

const _legacy = LocalArchiveIdentity(
  archiveId: 'legacy-archive',
  ownerKind: LocalArchiveOwnerKind.legacyUnclaimed,
  ownershipState: LocalArchiveOwnershipState.awaitingDecision,
);

JournalEntry _entry(String id, {String? owner, DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      ownerArchiveId: owner ?? SavedMomentLegacyAdapter.legacyUnscopedArchiveId,
      createdAt: createdAt ?? DateTime.utc(2026, 3, 2),
      transcript: 'saved words for $id',
      durationSeconds: 12,
      localAudioVaultRef: 'vault-$id',
      syncStatus: SyncStatus.pendingUpload,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: 'a',
        concreteObservation: 'b',
        repeatedSignal: 'c',
      ),
    );
