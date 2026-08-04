import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/data_ingestion/graph_ingestion_pipeline.dart';
import 'package:voicememory_mobile/features/data_ingestion/legacy_ingestion_store.dart';
import 'package:voicememory_mobile/features/data_ingestion/markdown_vault_parser.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'transactionally imports 100 notes and deduplicates a second run',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'legacy-pipeline-test-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      for (var index = 0; index < 100; index++) {
        final next = index < 99 ? '\nSee [[Note ${index + 1}]].' : '';
        await File('${root.path}/Note $index.md').writeAsString('''
---
tags: [batch, test]
created: 2026-01-01
---
This is the local body for note $index.$next
''');
      }

      final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
      final vectors = await SqliteVecVectorStore.open(
        databasePath: '${root.path}/vectors.sqlite3',
        dimensions: 4,
      );
      final store = await LegacyIngestionStore.open(
        databasePath: '${root.path}/legacy.sqlite3',
        codec: EncryptedSqliteTextCodec(() => Uint8List.fromList(key)),
        vectorStore: vectors,
      );
      final keyStore = InMemoryPrivateDataEncryptionKeyStore(seedKey: key);
      final graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/graph.enc'),
          keyStore: keyStore,
        ),
      );
      final embedder = _MockEmbeddingGenerator();
      final sweepQueue = _SweepQueue();
      final pipeline = GraphIngestionPipeline(
        parser: const MarkdownVaultParser(),
        store: store,
        graphStore: graphStore,
        embeddingGenerator: embedder,
        postImportSweepQueue: sweepQueue,
        noteBatchSize: 10,
      );
      addTearDown(() async {
        await pipeline.dispose();
        await graphStore.dispose();
        store.close();
      });

      final first = await pipeline.ingestDirectory(root);
      expect(first.parsedNotes, 100);
      expect(first.insertedNotes, 100);
      expect(first.skippedNotes, 0);
      expect(first.insertedChunks, 100);
      expect(first.insertedEdges, 99);
      expect(store.noteCount(), 100);
      expect(embedder.embeddedTexts, 100);
      expect(sweepQueue.enqueuedIds, hasLength(100));
      final graph = await graphStore.load();
      expect(graph.nodes.length, 100);
      expect(graph.edges.length, 99);

      final second = await pipeline.ingestDirectory(root);
      expect(second.insertedNotes, 0);
      expect(second.skippedNotes, 100);
      expect(store.noteCount(), 100);
      expect(embedder.embeddedTexts, 100);
      expect(sweepQueue.enqueuedIds, hasLength(100));
    },
  );
}

final class _SweepQueue implements LegacyPostImportSweepQueue {
  final Set<String> enqueuedIds = {};

  @override
  Future<void> enqueue(Iterable<String> noteIds) async {
    enqueuedIds.addAll(noteIds);
  }
}

final class _MockEmbeddingGenerator implements MarkdownEmbeddingGenerator {
  int embeddedTexts = 0;

  @override
  int get dimensions => 4;

  @override
  Future<List<Float32List>> embedBatch(List<String> texts) async {
    embeddedTexts += texts.length;
    return [
      for (var index = 0; index < texts.length; index++)
        Float32List.fromList([1, index.toDouble(), .5, .25]),
    ];
  }
}
