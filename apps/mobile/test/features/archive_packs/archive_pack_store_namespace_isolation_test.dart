import 'package:archiveme_mobile/features/archive_packs/archive_pack_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:flutter/services.dart';
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
  setUp(() {
    // `_switchToNamespace` persists the active namespace via
    // `SecureStorageService()` (not the in-memory store `resetForTest`
    // installs). Without this stub the unawaited write fails the suite
    // under `flutter test`.
    const secureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
          final args = call.arguments as Map<Object?, Object?>? ?? const {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureValues[key];
            case 'write':
              if (key != null) {
                secureValues[key] = args['value'] as String? ?? '';
              }
              return null;
            case 'containsKey':
              return key != null && secureValues.containsKey(key);
            case 'readAll':
              return Map<String, String>.of(secureValues);
            case 'delete':
              if (key != null) secureValues.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

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
