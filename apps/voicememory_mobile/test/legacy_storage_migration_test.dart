import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/account_namespace.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/legacy_storage_migration.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vm_legacy_migration_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
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

  Future<InMemoryPrivateDataEncryptionKeyStore> seedLegacyJournal(
    String base,
    List<JournalEntry> entries,
  ) async {
    // `flutter test` has no platform secure-storage plugin backing
    // `SecureStorageService`, so the default (non-test-injected) key store
    // used by `JournalStore.open` is a fresh in-memory key per call rather
    // than the persistent per-alias key production gets from the keychain.
    // Sharing one explicit key store between the seed write and the
    // migration's own read reproduces the "same key every open" guarantee
    // that holds for real devices.
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    final legacy = await JournalStore.open(
      '$base/journal_entries.json',
      keyStore: keyStore,
    );
    await legacy.replaceAll(entries);
    return keyStore;
  }

  test('migrates a legacy journal into the namespace directory', () async {
    final base = tempDir.path;
    final namespace = AccountNamespace.forUserId('user-1');
    final legacyKeyStore = await seedLegacyJournal(base, [
      sample(id: 'a'),
      sample(id: 'b', createdAt: DateTime.utc(2026, 1, 3)),
      sample(id: 'c', createdAt: DateTime.utc(2026, 1, 4)),
    ]);
    final destKeyStore = InMemoryPrivateDataEncryptionKeyStore();

    final report = await LegacyStorageMigration.migrateIfNeeded(
      base: base,
      namespace: namespace,
      legacyKeyStoreForTest: legacyKeyStore,
      destKeyStoreForTest: destKeyStore,
    );

    expect(report.ran, isTrue);
    expect(report.journalEntriesMigrated, 3);

    final destStore = await JournalStore.open(
      '$base/accounts/${namespace.key}/journal_entries.json',
      keyAlias: namespace.key,
      keyStore: destKeyStore,
    );
    final migrated = await destStore.loadAllIncludingTombstones();
    expect(migrated.map((e) => e.id).toSet(), {'a', 'b', 'c'});

    // Legacy file is left in place, untouched.
    expect(File('$base/journal_entries.enc').existsSync(), isTrue);
  });

  test(
    'running migration twice does not duplicate or corrupt entries',
    () async {
      final base = tempDir.path;
      final namespace = AccountNamespace.forUserId('user-2');
      final legacyKeyStore = await seedLegacyJournal(base, [
        sample(id: 'x'),
        sample(id: 'y'),
      ]);
      final destKeyStore = InMemoryPrivateDataEncryptionKeyStore();

      final first = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespace,
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStore,
      );
      expect(first.ran, isTrue);
      expect(first.journalEntriesMigrated, 2);

      final second = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespace,
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStore,
      );
      // The version marker is already stamped, so the second call is a no-op.
      expect(second.ran, isFalse);

      final destStore = await JournalStore.open(
        '$base/accounts/${namespace.key}/journal_entries.json',
        keyAlias: namespace.key,
        keyStore: destKeyStore,
      );
      final migrated = await destStore.loadAllIncludingTombstones();
      expect(migrated.length, 2);
      expect(migrated.map((e) => e.id).toSet(), {'x', 'y'});
    },
  );

  test(
    'idempotent even when re-invoked after simulating a crash mid-way',
    () async {
      final base = tempDir.path;
      final namespace = AccountNamespace.forUserId('user-3');
      final legacyKeyStore = await seedLegacyJournal(base, [
        sample(id: 'p'),
        sample(id: 'q'),
      ]);
      final destKeyStore = InMemoryPrivateDataEncryptionKeyStore();

      // Simulate a crash that migrated the journal but never stamped the
      // version marker, by invoking the private journal step's public
      // surface directly: just run the full migration once (this exercises
      // the same code path) and then delete the marker key while leaving the
      // already-migrated journal file behind, then re-run.
      await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespace,
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStore,
      );

      final destPrefsPath = '$base/accounts/${namespace.key}/mobile_prefs.json';
      final prefs = await MobilePrefsStore.open(destPrefsPath);
      // Clearing the marker re-arms the migration as if it never completed.
      await prefs.writeString(LegacyStorageMigration.versionPrefsKey, '0');

      final rerun = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespace,
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStore,
      );
      expect(rerun.ran, isTrue);
      expect(rerun.journalEntriesMigrated, 2);

      final destStore = await JournalStore.open(
        '$base/accounts/${namespace.key}/journal_entries.json',
        keyAlias: namespace.key,
        keyStore: destKeyStore,
      );
      final migrated = await destStore.loadAllIncludingTombstones();
      expect(migrated.length, 2);
      expect(migrated.map((e) => e.id).toSet(), {'p', 'q'});
    },
  );

  test(
    'cross-account isolation: a second account signing in on the same device never inherits the first account\'s stamped entries',
    () async {
      final base = tempDir.path;
      final namespaceA = AccountNamespace.forUserId('real-user-a');
      final namespaceB = AccountNamespace.forUserId('real-user-b');

      // The pre-namespacing shared journal, as it would exist on a device
      // used by two different accounts before this feature shipped:
      // entries stamped for each account, plus one predating ownership
      // stamping entirely (ownerKey null).
      final legacyKeyStore = await seedLegacyJournal(base, [
        JournalEntry(
          id: 'owned-by-a',
          createdAt: DateTime.utc(2026, 1, 1),
          transcript: 'account A private moment',
          durationSeconds: 10,
          reflection: sampleReflection(),
          ownerKey: 'real-user-a',
        ),
        JournalEntry(
          id: 'owned-by-b',
          createdAt: DateTime.utc(2026, 1, 2),
          transcript: 'account B private moment',
          durationSeconds: 10,
          reflection: sampleReflection(),
          ownerKey: 'real-user-b',
        ),
        JournalEntry(
          id: 'unowned-legacy',
          createdAt: DateTime.utc(2025, 12, 1),
          transcript: 'predates ownership stamping',
          durationSeconds: 10,
          reflection: sampleReflection(),
        ),
      ]);

      // Account A signs in first and migrates.
      final destKeyStoreA = InMemoryPrivateDataEncryptionKeyStore();
      final reportA = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespaceA,
        ownerUserId: 'real-user-a',
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStoreA,
      );
      expect(reportA.ran, isTrue);
      final storeA = await JournalStore.open(
        '$base/accounts/${namespaceA.key}/journal_entries.json',
        keyAlias: namespaceA.key,
        keyStore: destKeyStoreA,
      );
      final entriesA = await storeA.loadAllIncludingTombstones();
      expect(
        entriesA.map((e) => e.id).toSet(),
        {'owned-by-a', 'unowned-legacy'},
        reason:
            "account A must receive its own stamped entries and unowned "
            "legacy entries, but never account B's",
      );

      // Account B signs in later, on the exact same device, and migrates
      // from the same untouched legacy file.
      final destKeyStoreB = InMemoryPrivateDataEncryptionKeyStore();
      final reportB = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespaceB,
        ownerUserId: 'real-user-b',
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStoreB,
      );
      expect(reportB.ran, isTrue);
      final storeB = await JournalStore.open(
        '$base/accounts/${namespaceB.key}/journal_entries.json',
        keyAlias: namespaceB.key,
        keyStore: destKeyStoreB,
      );
      final entriesB = await storeB.loadAllIncludingTombstones();
      expect(
        entriesB.map((e) => e.id).toSet(),
        {'owned-by-b', 'unowned-legacy'},
        reason:
            "account B must receive its own stamped entries and unowned "
            "legacy entries, but never account A's",
      );

      // Account A's namespace must never have picked up B's entry either.
      expect(entriesA.map((e) => e.id), isNot(contains('owned-by-b')));
      expect(entriesB.map((e) => e.id), isNot(contains('owned-by-a')));
    },
  );

  test(
    'guest namespace migration only ever claims unowned legacy entries, never a real account\'s',
    () async {
      final base = tempDir.path;
      final legacyKeyStore = await seedLegacyJournal(base, [
        JournalEntry(
          id: 'owned',
          createdAt: DateTime.utc(2026, 1, 1),
          transcript: 'belongs to a real account',
          durationSeconds: 10,
          reflection: sampleReflection(),
          ownerKey: 'real-user-a',
        ),
        JournalEntry(
          id: 'unowned',
          createdAt: DateTime.utc(2025, 12, 1),
          transcript: 'guest-created',
          durationSeconds: 10,
          reflection: sampleReflection(),
        ),
      ]);

      final destKeyStore = InMemoryPrivateDataEncryptionKeyStore();
      final report = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: AccountNamespace.guest,
        legacyKeyStoreForTest: legacyKeyStore,
        destKeyStoreForTest: destKeyStore,
      );
      expect(report.ran, isTrue);

      final guestStore = await JournalStore.open(
        '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
        keyAlias: AccountNamespace.guest.key,
        keyStore: destKeyStore,
      );
      final guestEntries = await guestStore.loadAllIncludingTombstones();
      expect(guestEntries.map((e) => e.id).toSet(), {'unowned'});
    },
  );

  test('no-ops when there is no legacy data to relocate', () async {
    final base = tempDir.path;
    final namespace = AccountNamespace.guest;

    final report = await LegacyStorageMigration.migrateIfNeeded(
      base: base,
      namespace: namespace,
    );

    expect(report.ran, isFalse);
    expect(report.journalEntriesMigrated, 0);
    expect(
      File('$base/accounts/${namespace.key}/mobile_prefs.json').existsSync(),
      isFalse,
    );
  });

  test(
    'migrates legacy prefs without clobbering already-present destination keys',
    () async {
      final base = tempDir.path;
      final namespace = AccountNamespace.forUserId('user-4');

      final legacyPrefs = await MobilePrefsStore.open(
        '$base/mobile_prefs.json',
      );
      await legacyPrefs.writeBool('onboardingCompleted', true);
      await legacyPrefs.writeString('lastSyncAt', '2026-01-01T00:00:00.000Z');

      // Pre-seed the destination with a value that should win over the
      // legacy copy for that same key.
      final destPrefsPath = '$base/accounts/${namespace.key}/mobile_prefs.json';
      final destPrefs = await MobilePrefsStore.open(destPrefsPath);
      await destPrefs.writeBool('onboardingCompleted', false);

      final report = await LegacyStorageMigration.migrateIfNeeded(
        base: base,
        namespace: namespace,
      );
      expect(report.ran, isTrue);

      final afterMigration = await MobilePrefsStore.open(destPrefsPath);
      expect(await afterMigration.readBool('onboardingCompleted'), isFalse);
      expect(
        await afterMigration.readString('lastSyncAt'),
        '2026-01-01T00:00:00.000Z',
      );
    },
  );
}
