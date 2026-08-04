import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/neural_sculptor/neural_dataset_builder.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'builds deterministic pseudonymized JSONL and cleans plaintext',
    () async {
      final harness = await _DatasetHarness.create();
      addTearDown(harness.dispose);

      final manifest = await harness.builder.build();

      expect(manifest.recordCount, 1);
      expect(manifest.records.single.response, contains('[PERSON_1]'));
      expect(manifest.records.single.response, contains('[EMAIL]'));
      expect(manifest.records.single.response, contains('[DATE]'));
      expect(manifest.records.single.response, isNot(contains('Alice')));
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          harness.encryptedDataset,
          'Alice',
        ),
        isTrue,
      );

      final materialized = await harness.builder.materialize();
      final line = jsonDecode(await materialized.file.readAsString()) as Map;
      expect(line.keys, containsAll(<String>['instruction', 'response']));
      expect(line['response'], isNot(contains('Alice')));
      final directory = materialized.file.parent;
      await materialized.cleanup();
      expect(await directory.exists(), isFalse);
    },
  );

  test('startup cleanup removes stale plaintext training files', () async {
    final harness = await _DatasetHarness.create();
    addTearDown(harness.dispose);
    final stale = Directory(
      '${harness.root.path}/${NeuralDatasetBuilder.temporaryDirectoryName}/old',
    );
    await stale.create(recursive: true);
    final plaintext = File('${stale.path}/dataset.jsonl');
    await plaintext.writeAsString('private words');

    await harness.builder.cleanupStaleTemporaryFiles();

    expect(await plaintext.exists(), isFalse);
  });
}

final class _DatasetHarness {
  _DatasetHarness({
    required this.root,
    required this.builder,
    required this.encryptedDataset,
    required this.graphStore,
    required this.clusterStore,
  });

  final Directory root;
  final NeuralDatasetBuilder builder;
  final File encryptedDataset;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;

  static Future<_DatasetHarness> create() async {
    final root = await Directory.systemTemp.createTemp('neural_dataset_test_');
    final key = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => index),
    );
    final journal = await JournalStore.open(
      '${root.path}/journal.json',
      encryptAtRest: false,
    );
    await journal.save(
      JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 7, 20),
        transcript:
            'Alice emailed me at me@example.com on 2026-07-20 about the launch.',
        durationSeconds: 30,
        reflection: const Reflection(
          mood: 'hopeful',
          emotionalIntensity: 5,
          recurringThemes: ['launch'],
          exactLanguagePattern: 'about the launch',
          concreteObservation: 'I am preparing for the launch.',
          repeatedSignal: 'launch',
        ),
      ),
    );
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: key,
      ),
    );
    await graphStore.save(
      PersonalKnowledgeGraph(
        nodes: [
          GraphNode(
            type: NodeType.person,
            label: 'Alice',
            confidence: 1,
            evidence: [
              GraphNodeEvidence(
                entryId: 'entry-1',
                observedAt: DateTime.utc(2026, 7, 20),
                confidence: 1,
                excerpt: 'Alice',
                startUtf16: 0,
                endUtf16: 5,
              ),
            ],
          ),
        ],
      ),
    );
    final clusterStore = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/clusters.enc'),
        keyStore: key,
      ),
    );
    final encryptedDataset = File('${root.path}/dataset.enc');
    final builder = NeuralDatasetBuilder(
      journalStore: journal,
      graphStore: graphStore,
      clusterStore: clusterStore,
      encryptedStore: EncryptedJsonFileStore(
        file: encryptedDataset,
        keyStore: key,
      ),
      temporaryDirectory: () async => root,
    );
    return _DatasetHarness(
      root: root,
      builder: builder,
      encryptedDataset: encryptedDataset,
      graphStore: graphStore,
      clusterStore: clusterStore,
    );
  }

  Future<void> dispose() async {
    clusterStore.dispose();
    await graphStore.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
