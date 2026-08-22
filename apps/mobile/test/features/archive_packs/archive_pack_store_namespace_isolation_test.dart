import 'package:archiveme_mobile/features/archive_packs/archive_pack_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:flutter_test/flutter_test.dart';

/// `ArchivePackStore.instance()` needed no code changes to become
/// namespace-aware — it already reads/writes exclusively through
/// `AppServices.instance.prefs`, which is itself physically namespaced (see
/// `AppServices._switchToNamespace`). This test proves that composition
/// actually holds, rather than just asserting it by inspection.
int _uniqueSuffixCounter = 0;
String _uniqueSuffix() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_uniqueSuffixCounter++}';

void main() {
  test(
    'archive packs created under one account namespace are invisible after '
    'switching to a different namespace, and reappear when switching back',
    () async {
      final suffix = _uniqueSuffix();
      final namespaceA = AccountNamespace.forUserId('pack-acct-a-$suffix');
      final namespaceB = AccountNamespace.forUserId('pack-acct-b-$suffix');

      await AppServices.resetForTest(
        journalPath: '/tmp/vm_pack_isolation_test_$suffix.json',
        skipRevenueCat: true,
        namespace: namespaceA,
      );

      final packA = await ArchivePackStore.instance().create('Account A pack');
      expect(packA, isNotNull);
      final aPacks = await ArchivePackStore.instance().loadAll();
      expect(aPacks.map((p) => p.name), contains('Account A pack'));

      await AppServices.switchNamespaceForTest(namespaceB);
      final bPacksBeforeCreate = await ArchivePackStore.instance().loadAll();
      expect(
        bPacksBeforeCreate,
        isEmpty,
        reason: "Account B must not see account A's archive packs",
      );

      final packB = await ArchivePackStore.instance().create('Account B pack');
      expect(packB, isNotNull);

      await AppServices.switchNamespaceForTest(namespaceA);
      final aPacksAfterRoundTrip = await ArchivePackStore.instance().loadAll();
      expect(
        aPacksAfterRoundTrip.map((p) => p.name),
        contains('Account A pack'),
      );
      expect(
        aPacksAfterRoundTrip.map((p) => p.name),
        isNot(contains('Account B pack')),
      );
    },
  );
}