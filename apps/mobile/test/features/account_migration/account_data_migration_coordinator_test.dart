import 'package:archiveme_mobile/features/account_migration/account_data_migration_coordinator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test mints its own unique account id (never a fixed string) for
/// the same reason `app_services_account_switching_test.dart` does: the
/// guest namespace's on-disk path is otherwise shared/deterministic across
/// separate test runs against the same OS temp root, so a fixed id would
/// let one test's guest data leak into another.
int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

void main() {
  Reflection sampleReflection() => const Reflection(
    mood: 'calm',
    emotionalIntensity: 3,
    recurringThemes: ['reset'],
    exactLanguagePattern: 'starting over',
    concreteObservation: 'You mentioned starting fresh.',
    repeatedSignal: 'Fresh start mentioned twice.',
  );

  JournalEntry sample({required String id, required String transcript}) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 3),
      transcript: transcript,
      durationSeconds: 5,
      reflection: sampleReflection(),
    );
  }

  Future<AccountNamespace> resetForFreshAccount(String label) async {
    final suffix = _uniqueSuffix();
    final namespace = AccountNamespace.forUserId('$label-$suffix');
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_migration_coordinator_test_$suffix.json',
      skipRevenueCat: true,
      namespace: namespace,
    );
    return namespace;
  }

  Future<void> seedGuestEntries(List<JournalEntry> entries) async {
    final base = AppServices.instance.documentsBasePath;
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      encryptAtRest: false,
    );
    await guestStore.replaceAll(entries);
  }

  test(
    'hasMigratableGuestData is false when the guest namespace is empty',
    () async {
      await resetForFreshAccount('acct-empty-guest');
      final coordinator =
          await AccountDataMigrationCoordinator.forActiveAccount();
      expect(await coordinator.hasMigratableGuestData(), isFalse);
    },
  );

  test('hasMigratableGuestData is true when guest has data and the active '
      'account is still empty', () async {
    await resetForFreshAccount('acct-has-guest');
    await seedGuestEntries([sample(id: 'g1', transcript: 'guest thought')]);

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    expect(await coordinator.hasMigratableGuestData(), isTrue);
  });

  test('hasMigratableGuestData is false once the active account already has '
      'its own data', () async {
    await resetForFreshAccount('acct-already-has-data');
    await seedGuestEntries([sample(id: 'g1', transcript: 'guest thought')]);
    await AppServices.instance.journalStore.save(
      sample(id: 'own1', transcript: "account's own entry"),
    );

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    expect(await coordinator.hasMigratableGuestData(), isFalse);
  });

  test('migrateGuestDataIntoActiveAccount copies guest entries without '
      'clearing the guest namespace', () async {
    final namespace = await resetForFreshAccount('acct-migrate');
    await seedGuestEntries([
      sample(id: 'g1', transcript: 'first guest thought'),
      sample(id: 'g2', transcript: 'second guest thought'),
    ]);

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    final migrationId =
        AccountDataMigrationCoordinator.deterministicMigrationId(namespace);
    final result = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: migrationId,
    );

    expect(result.outcome, MigrationOutcome.migrated);
    expect(result.entriesCopied, 2);

    final activeEntries = await AppServices.instance.journalStore.loadAll();
    expect(activeEntries.map((e) => e.id), containsAll(['g1', 'g2']));

    // Guest namespace itself is untouched — "copy" is not "move".
    final base = AppServices.instance.documentsBasePath;
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      encryptAtRest: false,
    );
    final guestEntries = await guestStore.loadAll();
    expect(guestEntries.map((e) => e.id), containsAll(['g1', 'g2']));
  });

  test('calling migrateGuestDataIntoActiveAccount twice with the same '
      'migrationId does not duplicate entries', () async {
    final namespace = await resetForFreshAccount('acct-migrate-twice');
    await seedGuestEntries([sample(id: 'g1', transcript: 'guest thought')]);

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    final migrationId =
        AccountDataMigrationCoordinator.deterministicMigrationId(namespace);

    final first = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: migrationId,
    );
    expect(first.outcome, MigrationOutcome.migrated);

    final second = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: migrationId,
    );
    expect(second.outcome, MigrationOutcome.alreadyMigrated);

    final activeEntries = await AppServices.instance.journalStore
        .loadAllIncludingTombstones();
    expect(activeEntries.length, 1);
  });

  test('a completed Move clears the guest namespace only after the copy is '
      'verified', () async {
    final namespace = await resetForFreshAccount('acct-move');
    await seedGuestEntries([sample(id: 'g1', transcript: 'guest thought')]);

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    final migrationId =
        AccountDataMigrationCoordinator.deterministicMigrationId(namespace);
    final result = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: migrationId,
    );
    expect(result.outcome, MigrationOutcome.migrated);

    // Active copy verified present before we let go of the guest copy.
    expect(
      (await AppServices.instance.journalStore.loadAll()).map((e) => e.id),
      contains('g1'),
    );

    await coordinator.clearGuestDataAfterVerifiedMove();

    final base = AppServices.instance.documentsBasePath;
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      encryptAtRest: false,
    );
    expect(await guestStore.loadAll(), isEmpty);

    // The active account's own copy survives the guest-side clear.
    expect(
      (await AppServices.instance.journalStore.loadAll()).map((e) => e.id),
      contains('g1'),
    );
  });

  test('"Keep separate" persists a decision and never touches guest or '
      'active data', () async {
    await resetForFreshAccount('acct-keep-separate');
    await seedGuestEntries([sample(id: 'g1', transcript: 'guest thought')]);

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    expect(await coordinator.recordedDecision(), isNull);

    await coordinator.recordKeptSeparateDecision();
    expect(await coordinator.recordedDecision(), 'kept_separate');

    expect(await AppServices.instance.journalStore.loadAll(), isEmpty);
    final base = AppServices.instance.documentsBasePath;
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      encryptAtRest: false,
    );
    expect((await guestStore.loadAll()).map((e) => e.id), contains('g1'));
  });

  test('exportGuestData exports only the guest namespace, never the active '
      "account's own data", () async {
    await resetForFreshAccount('acct-export');
    await seedGuestEntries([
      sample(id: 'g1', transcript: 'guest secret thought'),
    ]);
    await AppServices.instance.journalStore.save(
      sample(id: 'own1', transcript: "account's own private thought"),
    );

    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    final payload = await coordinator.exportGuestData();

    expect(payload.entries.length, 1);
    expect(
      payload.entries.single['transcript'],
      contains('guest secret thought'),
    );
  });

  test('migrating while the guest namespace is itself active is not '
      'applicable (there is nothing to migrate "into")', () async {
    await AppServices.resetForTest(
      journalPath:
          '/tmp/vm_migration_coordinator_test_guest_${_uniqueSuffix()}.json',
      skipRevenueCat: true,
      namespace: AccountNamespace.guest,
    );
    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    expect(await coordinator.hasMigratableGuestData(), isFalse);

    final result = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: 'irrelevant',
    );
    expect(result.outcome, MigrationOutcome.notApplicable);
  });

  test("structural guard: this coordinator's only possible data source is the "
      "guest namespace — a second signed-in account's own namespaced data is "
      'never reachable through it, since there is no source parameter to '
      'point at it', () async {
    // Set up account A with its own private data, signed in.
    final namespaceA = await resetForFreshAccount('acct-guard-a');
    await AppServices.instance.journalStore.save(
      sample(id: 'a-private', transcript: "A's private thought"),
    );

    // Switch to account B — a completely different signed-in account,
    // not the guest namespace.
    final namespaceB = AccountNamespace.forUserId(
      'acct-guard-b-${_uniqueSuffix()}',
    );
    await AppServices.switchNamespaceForTest(namespaceB);

    // Even though A's namespaced file physically exists on disk right
    // next to the guest namespace's, the coordinator for B's session has
    // no way to name A's namespace as a source — it can only ever read
    // the hardcoded guest path.
    final coordinator =
        await AccountDataMigrationCoordinator.forActiveAccount();
    final result = await coordinator.migrateGuestDataIntoActiveAccount(
      migrationId: AccountDataMigrationCoordinator.deterministicMigrationId(
        namespaceB,
      ),
    );
    expect(result.outcome, MigrationOutcome.noGuestData);

    final bEntries = await AppServices.instance.journalStore.loadAll();
    expect(bEntries.map((e) => e.id), isNot(contains('a-private')));

    await AppServices.switchNamespaceForTest(namespaceA);
  });
}