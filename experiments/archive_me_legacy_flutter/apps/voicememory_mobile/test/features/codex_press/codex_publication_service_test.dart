import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/codex_press/codex_compiler.dart';
import 'package:voicememory_mobile/features/codex_press/codex_encryption_manager.dart';
import 'package:voicememory_mobile/features/codex_press/codex_models.dart';
import 'package:voicememory_mobile/features/codex_press/codex_publication_service.dart';
import 'package:voicememory_mobile/features/codex_press/codex_renderers.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

import 'codex_renderers_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codex-service-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'writes atomically, redacts history paths, and cleans lifecycle state',
    () async {
      final service = _service(root, authorize: true);
      final file = await service.exportPlaintext(
        manuscript: sampleCodexManuscript(),
        format: CodexExportFormat.offlineHtml,
        warningAccepted: true,
      );
      expect(await file.exists(), isTrue);
      expect(
        await Directory(
          '${root.path}/exports',
        ).list().where((item) => item.path.endsWith('.part')).isEmpty,
        isTrue,
      );
      final records = await service.history.list();
      expect(records.single.format, CodexExportFormat.offlineHtml);
      expect(records.single.toJson().values, isNot(contains(file.path)));

      final stale = File('${root.path}/exports/stale.part');
      await stale.writeAsString('plaintext');
      await service.onLockOrRestore();
      expect(await stale.exists(), isFalse);

      await service.wipe();
      expect(await Directory('${root.path}/exports').exists(), isFalse);
      expect(await service.history.list(), isEmpty);
    },
  );

  test('plaintext export requires warning and owner authorization', () async {
    final service = _service(root, authorize: false);
    expect(
      () => service.exportPlaintext(
        manuscript: sampleCodexManuscript(),
        format: CodexExportFormat.pdf,
        warningAccepted: true,
      ),
      throwsA(isA<CodexAuthenticationException>()),
    );
  });
}

CodexPublicationService _service(Directory root, {required bool authorize}) {
  final keyStore = InMemoryPrivateDataEncryptionKeyStore();
  return CodexPublicationService(
    compiler: CodexCompiler.loaders(
      graphLoader: () async => PersonalKnowledgeGraph(),
      clusterLoader: () async => [],
      journalLoader: () async => [],
      audioLoader: () async => [],
      transcriptLoader: (_) async => null,
    ),
    renderer: const CodexRenderer(),
    encryptionManager: CodexEncryptionManager(
      random: Random(1),
      passwordIterations: 1000,
      recoveryKeyProvider: () async => null,
    ),
    history: CodexPublicationHistoryStore(
      EncryptedJsonFileStore(
        file: File('${root.path}/history.enc'),
        keyStore: keyStore,
      ),
    ),
    exportsDirectory: Directory('${root.path}/exports'),
    authenticateOwner: (_) async => authorize,
  );
}
