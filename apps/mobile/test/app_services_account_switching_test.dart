import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:flutter_test/flutter_test.dart';

/// The single most important correctness test in this task: proves that
/// switching the active account namespace physically swaps
/// `AppServices.instance.journalStore` (and everything derived from it) so
/// one account's entries are never visible while a different account is
/// active, and are still intact when switching back.
///
/// Every test below mints its own unique pair of account ids (rather than
/// fixed strings) — `AccountNamespace.forUserId` is deterministic, and
/// `AppServices.resetForTest`'s namespaced paths hang off the *shared* OS
/// temp directory, so reusing a fixed id across test runs (in this file or
/// any other) would let one test's leftover on-disk namespace directory
/// leak into another test that happens to pick the same id.
int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

void main() {
  Reflection sampleReflection() => const Reflection(
    mood: 'calm',
    emotionalIntensity: 4,
    recurringThemes: ['work'],
    exactLanguagePattern: 'I need a break',
    concreteObservation: 'You mentioned needing a break.',
    repeatedSignal: 'Break mentioned twice.',
  );

  JournalEntry sample({required String id, required String transcript}) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 2),
      transcript: transcript,
      durationSeconds: 12,
      reflection: sampleReflection(),
    );
  }

  Future<AccountNamespace> resetForFreshAccount(String label) async {
    final suffix = _uniqueSuffix();
    final namespace = AccountNamespace.forUserId('$label-$suffix');
    await AppServices.resetForTest(
      journalPath:
          '${Directory.systemTemp.path}/vm_switch_test_journal_$suffix.json',
      skipRevenueCat: true,
      namespace: namespace,
    );
    return namespace;
  }

  test('switching accounts physically isolates journal data, and switching '
      'back restores it', () async {
    final namespaceA = await resetForFreshAccount('account-a');
    final namespaceB = AccountNamespace.forUserId(
      'account-b-${_uniqueSuffix()}',
    );

    expect(AppServices.instance.activeNamespace, namespaceA);

    // Account A saves an entry.
    await AppServices.instance.journalStore.save(
      sample(id: 'a-entry-1', transcript: 'Account A private thought'),
    );
    final aEntries = await AppServices.instance.journalStore.loadAll();
    expect(aEntries.map((e) => e.id), contains('a-entry-1'));

    // Sign out then sign in as a different account (B).
    await AppServices.switchNamespaceForTest(AccountNamespace.guest);
    expect(AppServices.instance.activeNamespace, AccountNamespace.guest);

    await AppServices.switchNamespaceForTest(namespaceB);
    expect(AppServices.instance.activeNamespace, namespaceB);

    final bEntries = await AppServices.instance.journalStore.loadAll();
    expect(
      bEntries.map((e) => e.id),
      isNot(contains('a-entry-1')),
      reason: "Account B's journal must never contain account A's entry",
    );
    expect(bEntries, isEmpty);

    // B saves its own, differently-identified entry.
    await AppServices.instance.journalStore.save(
      sample(id: 'b-entry-1', transcript: 'Account B private thought'),
    );
    final bEntriesAfterSave = await AppServices.instance.journalStore.loadAll();
    expect(bEntriesAfterSave.map((e) => e.id), contains('b-entry-1'));
    expect(bEntriesAfterSave.map((e) => e.id), isNot(contains('a-entry-1')));

    // Switch back to account A — its data must still be there, and B's
    // entry must not have leaked into it.
    await AppServices.switchNamespaceForTest(namespaceA);
    expect(AppServices.instance.activeNamespace, namespaceA);

    final aEntriesAfterRoundTrip = await AppServices.instance.journalStore
        .loadAll();
    expect(
      aEntriesAfterRoundTrip.map((e) => e.id),
      contains('a-entry-1'),
      reason: 'Switching back to account A must restore its data',
    );
    expect(
      aEntriesAfterRoundTrip.map((e) => e.id),
      isNot(contains('b-entry-1')),
      reason: "Account A's journal must never contain account B's entry",
    );
    expect(aEntriesAfterRoundTrip.length, 1);
  });

  test(
    'sync always operates on the currently-active journalStore after a switch',
    () async {
      await resetForFreshAccount('account-a');
      final namespaceB = AccountNamespace.forUserId(
        'account-b-${_uniqueSuffix()}',
      );

      final syncBeforeSwitch = AppServices.instance.sync;
      final journalStoreBeforeSwitch = AppServices.instance.journalStore;

      await AppServices.switchNamespaceForTest(namespaceB);

      final syncAfterSwitch = AppServices.instance.sync;
      expect(
        syncAfterSwitch,
        isNot(same(syncBeforeSwitch)),
        reason: 'sync must be rebuilt against the new namespace, not reused',
      );
      expect(
        AppServices.instance.journalStore,
        isNot(same(journalStoreBeforeSwitch)),
      );
    },
  );

  test('switching to the already-active namespace is a no-op', () async {
    final namespaceA = await resetForFreshAccount('account-a');

    final journalStoreBefore = AppServices.instance.journalStore;
    final pipelineBefore = AppServices.instance.pipeline;

    await AppServices.switchNamespaceForTest(namespaceA);

    expect(AppServices.instance.journalStore, same(journalStoreBefore));
    expect(AppServices.instance.pipeline, same(pipelineBefore));
  });

  test('two different accounts can independently use the same entry id without '
      'collision, since each lives in a separate namespace file', () async {
    final namespaceA = await resetForFreshAccount('account-a');
    final namespaceB = AccountNamespace.forUserId(
      'account-b-${_uniqueSuffix()}',
    );

    await AppServices.instance.journalStore.save(
      sample(id: 'shared-id', transcript: "A's version"),
    );

    await AppServices.switchNamespaceForTest(namespaceB);
    await AppServices.instance.journalStore.save(
      sample(id: 'shared-id', transcript: "B's version"),
    );

    final bVersion = await AppServices.instance.journalStore.getById(
      'shared-id',
    );
    expect(bVersion?.transcript, "B's version");

    await AppServices.switchNamespaceForTest(namespaceA);
    final aVersion = await AppServices.instance.journalStore.getById(
      'shared-id',
    );
    expect(aVersion?.transcript, "A's version");
  });
}