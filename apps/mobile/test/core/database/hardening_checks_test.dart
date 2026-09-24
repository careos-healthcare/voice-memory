import 'dart:convert';

import 'package:archiveme_mobile/core/database/database_initializer.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_json_parser.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_tagging_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/sync/cloud_relay_service.dart';
import 'package:archiveme_mobile/features/sync/secure_key_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sqlite-vec load failure keeps blob ranking and does not throw',
    () async {
      configureSqliteTestFfi();
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      expect(
        DatabaseInitializer.darwinFactory.toString(),
        contains('SqfliteDarwin'),
      );
      final loaded = await DatabaseInitializer.loadSqliteVec(db);

      expect(loaded, isFalse);
      expect(DatabaseInitializer.vecExtensionLoaded, isFalse);
      await db.execute(
        'CREATE TABLE similarity_rank (id TEXT PRIMARY KEY, embedding BLOB)',
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'similarity_rank'",
      );
      expect(tables, isNotEmpty);
    },
  );

  test('first boot stores one 256-bit key for the cloud relay', () async {
    final previous = FlutterSecureStoragePlatform.instance;
    final memory = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      memory,
    );
    addTearDown(() {
      FlutterSecureStoragePlatform.instance = previous;
      PremiumAccess.apply(PremiumEntitlement.free);
    });

    final keys = SecureKeyManager(secureStorage: const FlutterSecureStorage());
    final created = await keys.loadOrCreate();
    final again = await keys.loadOrCreate();

    expect(created, hasLength(SecureKeyManager.keyByteLength));
    expect(again, created);
    expect(memory[SecureKeyManager.defaultStorageKey], isNotNull);
    expect(base64Decode(memory[SecureKeyManager.defaultStorageKey]!), created);

    PremiumAccess.apply(PremiumEntitlement.active);
    final relay = await CloudRelayService.fromBootKey(keys: keys);
    const transcript = 'rent is due';
    final envelope = await relay.relayIfSecondaryOffline(
      peerObserved: false,
      recordingId: 'rec-1',
      audioBytes: [1, 2, 3],
      transcript: transcript,
    );
    expect(envelope, isNotNull);
    expect(envelope!.payload.ciphertext.contains('rent is due'), isFalse);
    final pulled = await relay.pullAndDecrypt();
    expect(pulled.single.transcript, transcript);
  });

  test('gemma parser strips fences, prose, and trailing commas', () {
    const fenced = '''
Here is the result:
```json
{"tags":["solar","panel","roof",],"folder":"Home",}
```
Let me know if you want more.
''';
    final decoded = decodeGemmaJson(fenced);
    expect(decoded, {
      'tags': ['solar', 'panel', 'roof'],
      'folder': 'Home',
    });

    final parsed = parseContextTagJson(fenced);
    expect(parsed!.tags, ['solar', 'panel', 'roof']);
    expect(parsed.folder, 'Home');
    expect(decodeGemmaJson('no json here'), isNull);
  });
}
