import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/sanctuary_core/sanctuary_health_engine.dart';
import 'package:voicememory_mobile/features/sanctuary_core/sanctuary_models.dart';
import 'package:voicememory_mobile/features/whispering_vault/audio_vault_storage.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/local_storage/browser_bridge_vault.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('audits keys, exact storage bytes, and SQLite corruption', () async {
    final root = await Directory.systemTemp.createTemp('sanctuary_health_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/personal_knowledge_graph.enc'),
        keyStore: keyStore,
      ),
    );
    await graphStore.save(PersonalKnowledgeGraph(nodes: [_node()]));
    final semantic = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/hybrid_local_semantic.enc'),
        keyStore: keyStore,
      ),
    );
    await semantic.upsertMediaMemory(
      sourceNodeId: 'source',
      searchableText: 'private local sanctuary',
      nodeIds: const ['node'],
      tags: const ['test'],
    );
    final audioKeys = VaultKeyProvider.testing();
    final audio = AudioVaultStorage.open(
      databasePath: '${root.path}/whispering_vault.sqlite3',
      keyStore: audioKeys.getOrCreateMasterKey,
    );
    final browser = BrowserBridgeVault.open(
      databasePath: '${root.path}/browser_bridge.sqlite3',
      keyStore: keyStore,
    );
    final healthyPath = '${root.path}/healthy.sqlite3';
    sqlite3.open(healthyPath)
      ..execute('CREATE TABLE sample(id INTEGER PRIMARY KEY)')
      ..close();
    final corruptPath = '${root.path}/corrupt.sqlite3';
    await File(corruptPath).writeAsString('not a sqlite database');
    await EncryptedJsonFileStore(
      file: File('${root.path}/apex_audits/healthy.apex-audit'),
      keyStore: keyStore,
    ).writeJson({'schema': 'archive-me.apex-audit'});
    await File(
      '${root.path}/apex_audits/corrupt.apex-audit',
    ).writeAsString('not an encrypted envelope');

    final engine = SanctuaryHealthEngine(
      root: root,
      graphStore: graphStore,
      audioVault: audio,
      semanticStore: semantic,
      browserVault: browser,
      privateKeyValid: () async => true,
      audioKeyValid: () async => true,
      sqlitePaths: [healthyPath, corruptPath],
      clock: () => DateTime.utc(2026, 7, 28),
    );
    final report = await engine.audit();

    expect(
      report.diagnostics
          .singleWhere((item) => item.id == 'sqlite:healthy.sqlite3')
          .status,
      SanctuaryCheckStatus.healthy,
    );
    expect(
      report.diagnostics
          .singleWhere((item) => item.id == 'sqlite:corrupt.sqlite3')
          .status,
      SanctuaryCheckStatus.failed,
    );
    expect(
      report.diagnostics
          .singleWhere((item) => item.id == 'apex:healthy.apex-audit')
          .status,
      SanctuaryCheckStatus.healthy,
    );
    expect(
      report.diagnostics
          .singleWhere((item) => item.id == 'apex:corrupt.apex-audit')
          .status,
      SanctuaryCheckStatus.failed,
    );
    final graphMetric = report.storage.singleWhere(
      (item) => item.kind == SanctuaryStorageKind.memoryGraph,
    );
    expect(
      graphMetric.bytes,
      await File('${root.path}/personal_knowledge_graph.enc').length(),
    );
    expect(graphMetric.itemCount, 1);
    expect(
      report.storage
          .singleWhere((item) => item.kind == SanctuaryStorageKind.embeddings)
          .itemCount,
      1,
    );

    browser.close();
    audio.close();
    await semantic.dispose();
    await graphStore.dispose();
  });
}

GraphNode _node() {
  const label = 'Sovereign memory';
  return GraphNode(
    id: 'node',
    type: NodeType.memory,
    label: label,
    confidence: .9,
    evidence: [
      GraphNodeEvidence(
        entryId: 'entry',
        observedAt: DateTime.utc(2026, 1, 1),
        confidence: .9,
        excerpt: label,
        startUtf16: 0,
        endUtf16: label.length,
      ),
    ],
  );
}
