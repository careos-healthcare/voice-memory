import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/account_namespace.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

/// Unique per test, for the same reason the other namespacing tests are:
/// the on-disk `accounts/<key>` directory a fixed id resolves to is shared
/// across test runs against the same temp root.
int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Reflection sampleReflection() => const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['wipe-test'],
    exactLanguagePattern: 'clearing my head',
    concreteObservation: 'You mentioned clearing your head.',
    repeatedSignal: 'Clearing mentioned twice.',
  );

  JournalEntry sample(String id) => JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 4, 1),
    transcript: 'entry $id',
    durationSeconds: 6,
    reflection: sampleReflection(),
    syncStatus: SyncStatus.localOnly,
  );

  test("wiping account A's namespace via PrivateDataService leaves account "
      "B's namespace directory on disk untouched", () async {
    final suffix = _uniqueSuffix();
    final namespaceA = AccountNamespace.forUserId('wipe-a-$suffix');
    final namespaceB = AccountNamespace.forUserId('wipe-b-$suffix');

    await AppServices.resetForTest(
      journalPath: '/tmp/vm_wipe_test_journal_$suffix.json',
      skipRevenueCat: true,
      namespace: namespaceA,
    );
    await AppServices.instance.journalStore.save(sample('a-entry'));

    await AppServices.switchNamespaceForTest(namespaceB);
    await AppServices.instance.journalStore.save(sample('b-entry'));

    final base = AppServices.instance.documentsBasePath;
    final namespaceADir = Directory('$base/accounts/${namespaceA.key}');
    final namespaceBDir = Directory('$base/accounts/${namespaceB.key}');
    expect(namespaceADir.existsSync(), isTrue);
    expect(namespaceBDir.existsSync(), isTrue);

    // Switch back to A and wipe *only* A's local archive.
    await AppServices.switchNamespaceForTest(namespaceA);
    final service = PrivateDataService(
      journalStore: AppServices.instance.journalStore,
      prefs: AppServices.instance.prefs,
      tempDirProvider: () async => Directory.systemTemp,
    );
    await service.clearLocalArchiveData();

    expect(await AppServices.instance.journalStore.loadAll(), isEmpty);

    // B's on-disk namespace directory — and its data — must be intact.
    expect(namespaceBDir.existsSync(), isTrue);
    await AppServices.switchNamespaceForTest(namespaceB);
    final bEntries = await AppServices.instance.journalStore.loadAll();
    expect(bEntries.map((e) => e.id), contains('b-entry'));
  });

  test('PrivateDataService.wipeAllAccountsOnDevice deletes every namespace '
      'directory under accounts/, guest included', () async {
    final suffix = _uniqueSuffix();
    final namespaceA = AccountNamespace.forUserId('wipe-all-a-$suffix');
    final namespaceB = AccountNamespace.forUserId('wipe-all-b-$suffix');

    await AppServices.resetForTest(
      journalPath: '/tmp/vm_wipe_all_test_journal_$suffix.json',
      skipRevenueCat: true,
      namespace: namespaceA,
    );
    final base = AppServices.instance.documentsBasePath;

    // Seed A (active), B, and guest namespaces directly on disk.
    await AppServices.instance.journalStore.save(sample('a-entry'));
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      encryptAtRest: false,
    );
    await guestStore.save(sample('guest-entry'));
    await AppServices.switchNamespaceForTest(namespaceB);
    await AppServices.instance.journalStore.save(sample('b-entry'));

    final wipedCount = await PrivateDataService.wipeAllAccountsOnDevice(
      documentsBasePath: base,
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );
    expect(wipedCount, greaterThanOrEqualTo(3));

    expect(Directory('$base/accounts/${namespaceA.key}').existsSync(), isFalse);
    expect(Directory('$base/accounts/${namespaceB.key}').existsSync(), isFalse);
    expect(
      Directory('$base/accounts/${AccountNamespace.guest.key}').existsSync(),
      isFalse,
    );
    expect(Directory('$base/accounts').existsSync(), isTrue);
  });

  test('wipeAllAccountsOnDevice rejects a mismatched confirmation phrase and '
      'deletes nothing', () async {
    final suffix = _uniqueSuffix();
    final namespace = AccountNamespace.forUserId('wipe-all-guard-$suffix');
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_wipe_all_guard_test_journal_$suffix.json',
      skipRevenueCat: true,
      namespace: namespace,
    );
    final base = AppServices.instance.documentsBasePath;

    expect(
      () => PrivateDataService.wipeAllAccountsOnDevice(
        documentsBasePath: base,
        confirmationPhrase: 'not the right phrase',
      ),
      throwsArgumentError,
    );
    expect(Directory('$base/accounts/${namespace.key}').existsSync(), isTrue);
  });
}
