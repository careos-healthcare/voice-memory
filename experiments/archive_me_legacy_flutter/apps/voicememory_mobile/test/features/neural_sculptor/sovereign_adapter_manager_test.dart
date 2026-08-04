import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/neural_sculptor/sovereign_adapter_manager.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'encrypts, activates, switches, exports, and unloads adapters',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'adapter_manager_test_',
      );
      final keyBytes = Uint8List.fromList(List<int>.filled(32, 9));
      final runtime = _FakeAdapterRuntime();
      final manager = await SovereignAdapterManager.open(
        databasePath: '${root.path}/adapters.sqlite3',
        codec: EncryptedSqliteTextCodec(() => Uint8List.fromList(keyBytes)),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: keyBytes),
        adapterDirectory: Directory('${root.path}/adapters'),
        runtimeDirectory: Directory('${root.path}/runtime'),
        runtime: runtime,
        activeBaseModelFingerprint: () async => 'base-hash',
        ownerAuthenticator: (_) async => true,
      );
      addTearDown(() async {
        manager.close();
        if (await root.exists()) await root.delete(recursive: true);
      });
      final safe = File('${root.path}/source.safetensors')
        ..writeAsBytesSync([1, 2, 3]);
      final gguf = File('${root.path}/source.gguf')
        ..writeAsBytesSync([4, 5, 6]);
      final adapter = await manager.importTrained(
        name: 'My Voice',
        safetensors: safe,
        ggufAdapter: gguf,
        baseModelSha256: 'base-hash',
        rank: 8,
        targetModules: const ['q_proj'],
        finalLoss: .2,
        tokenCount: 100,
      );

      expect(
        await File(adapter.safetensorsArtifact).readAsString(),
        isNot(contains(String.fromCharCodes([1, 2, 3]))),
      );
      await manager.activate(adapter.id);
      expect(manager.active?.id, adapter.id);
      expect(runtime.loadedPath, isNotNull);
      expect(File(runtime.loadedPath!).existsSync(), isTrue);

      final exported = await manager.exportSafetensors(
        adapter.id,
        File('${root.path}/export.safetensors'),
      );
      expect(await exported!.readAsBytes(), [1, 2, 3]);
      await manager.cleanupExport(exported);
      expect(await exported.exists(), isFalse);

      await manager.unload();
      expect(manager.active, isNull);
      expect(runtime.unloadCount, greaterThan(0));
      expect(File(runtime.loadedPath!).existsSync(), isFalse);
    },
  );
}

final class _FakeAdapterRuntime implements AdapterRuntimeController {
  String? loadedPath;
  var unloadCount = 0;

  @override
  Future<void> load(String ggufPath, {double scale = 1}) async {
    loadedPath = ggufPath;
  }

  @override
  Future<void> unload() async => unloadCount++;
}
