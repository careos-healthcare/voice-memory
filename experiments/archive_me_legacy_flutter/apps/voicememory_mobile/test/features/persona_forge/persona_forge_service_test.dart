import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/cognitive_council/council_persona.dart';
import 'package:voicememory_mobile/features/persona_forge/persona_forge_service.dart';
import 'package:voicememory_mobile/features/persona_forge/persona_knowledge_router.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'encrypted SQLite CRUD preserves custom persona configuration',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      final created = await harness.service.create(
        name: 'Venture Cartographer',
        archetypeTitle: 'Startup strategist',
        systemPrompt: 'Challenge assumptions with grounded evidence.',
        temperature: .35,
        restrictedClusterIds: const {'startup'},
        avatarAsset: 'compass',
      );
      expect((await harness.service.list()).single.name, created.name);
      final sqliteBytes = File(harness.service.databasePath).readAsBytesSync();
      expect(
        latin1
            .decode(sqliteBytes)
            .contains('Challenge assumptions with grounded evidence.'),
        isFalse,
      );

      final updated = await harness.service.update(
        created.copyWith(temperature: .8, name: 'Venture Navigator'),
      );
      expect((await harness.service.get(created.id))!.temperature, .8);
      expect(updated.name, 'Venture Navigator');

      await harness.service.delete(created.id);
      expect(await harness.service.list(), isEmpty);
    },
  );

  test(
    'knowledge router excludes every node outside granted clusters',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final semanticStorage = EncryptedJsonFileStore(
        file: File('${harness.root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      final clusterStorage = EncryptedJsonFileStore(
        file: File('${harness.root.path}/clusters.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      final semantic = LocalSemanticStore(storage: semanticStorage);
      final clusters = SemanticClusterStore(storage: clusterStorage);
      addTearDown(semantic.dispose);
      addTearDown(clusters.dispose);
      await semantic.upsertMediaMemory(
        sourceNodeId: 'entry-startup',
        searchableText: 'startup product growth launch',
        nodeIds: const ['node-startup'],
        tags: const ['project'],
      );
      await semantic.upsertMediaMemory(
        sourceNodeId: 'entry-health',
        searchableText: 'health sleep recovery',
        nodeIds: const ['node-health'],
        tags: const ['habit'],
      );
      await clusters.replace([
        SemanticCluster(
          id: 'startup',
          title: 'Startup',
          category: SemanticClusterCategory.project,
          nodeIds: const ['node-startup'],
          activityVelocity: .7,
          confidenceScore: .9,
        ),
        SemanticCluster(
          id: 'health',
          title: 'Health',
          category: SemanticClusterCategory.habitCluster,
          nodeIds: const ['node-health'],
          activityVelocity: .4,
          confidenceScore: .8,
        ),
      ]);
      final graph = PersonalKnowledgeGraph(
        nodes: [
          GraphNode(
            id: 'node-startup',
            type: NodeType.project,
            label: 'Private startup plan',
            confidence: 1,
            origin: NodeOrigin.manual,
          ),
          GraphNode(
            id: 'node-health',
            type: NodeType.habit,
            label: 'Private health routine',
            confidence: 1,
            origin: NodeOrigin.manual,
          ),
        ],
      );
      final router = PersonaKnowledgeRouter(
        semanticStore: semantic,
        clusterStore: clusters,
        graphLoader: () async => graph,
      );
      final request = await router.buildInvocation(
        persona: CouncilPersona(
          id: 'persona',
          name: 'Founder',
          archetypeTitle: 'Strategist',
          systemPrompt: 'Use scoped evidence.',
          temperature: .4,
          restrictedClusterIds: const {'startup'},
        ),
        userMessage: 'How should I improve startup growth and health?',
      );

      expect(request.context.nodes.single['id'], 'node-startup');
      expect(
        request.context.nodes.any((node) => node['id'] == 'node-health'),
        isFalse,
      );
      expect(request.toJson()['store'], isFalse);
      expect(
        PersonaInvocationRequest.nonRetentionHeaders['X-Data-Retention'],
        'none',
      );
    },
  );

  test(
    '.persona export imports intact with an independent local key',
    () async {
      final source = await _Harness.create();
      final target = await _Harness.create();
      addTearDown(source.dispose);
      addTearDown(target.dispose);
      final persona = await source.service.create(
        name: 'Reflective Sage',
        archetypeTitle: 'Biographical coach',
        systemPrompt: 'Respond with care and precision.',
        localizedSystemPrompts: const {'fr': 'Répondez avec soin.'},
        temperature: .25,
        restrictedClusterIds: const {'identity', 'health'},
      );
      final file = File('${source.root.path}/sage.persona');
      await source.service.exportPersona(
        persona: persona,
        output: file,
        passphrase: 'correct horse battery staple',
      );

      final imported = await target.service.importPersona(
        input: file,
        passphrase: 'correct horse battery staple',
      );
      expect(imported.toJson(), persona.toJson());
      expect(imported.promptForLocale('fr-FR'), 'Répondez avec soin.');
    },
  );
}

final class _Harness {
  _Harness(this.root, this.service);

  final Directory root;
  final PersonaForgeService service;

  static Future<_Harness> create() async {
    final root = Directory.systemTemp.createTempSync('persona_forge_test_');
    final service = PersonaForgeService.open(
      databasePath: '${root.path}/personas.sqlite3',
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    return _Harness(root, service);
  }

  Future<void> dispose() async {
    service.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
