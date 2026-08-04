import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/features/whispering_vault/audio_graph_mapper.dart';
import 'package:voicememory_mobile/features/whispering_vault/audio_vault_storage.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('maps local transcript into cited nodes and thematic cluster', () async {
    final root = Directory.systemTemp.createTempSync('audio_mapper_test_');
    final keys = InMemoryPrivateDataEncryptionKeyStore();
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: keys,
      ),
    );
    final clusterStore = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/clusters.enc'),
        keyStore: keys,
      ),
    );
    await clusterStore.upsert(
      SemanticCluster(
        id: 'career',
        title: 'Career planning',
        category: SemanticClusterCategory.project,
        nodeIds: const [],
        activityVelocity: .2,
        confidenceScore: .8,
      ),
    );
    final mapper = AudioGraphMapper(
      graphStore: graphStore,
      clusterStore: clusterStore,
      clock: () => DateTime.utc(2026, 7, 28),
    );

    final result = await mapper.mapTranscript(
      audioId: 'audio-1',
      transcript:
          'I feel hopeful about my career. I need to prepare the portfolio.',
    );

    expect(result.nodes, hasLength(2));
    expect(result.nodes.first.type.name, 'emotion');
    expect(result.nodes.last.type.name, 'actionItem');
    expect(result.nodes.every((node) => node.hasValidEvidence), isTrue);
    expect(result.edges, hasLength(1));
    expect(result.clusterIds, contains('career'));
    expect(result.emotionalValence, greaterThan(0));
    expect((await graphStore.load()).nodes, hasLength(2));
    final career = (await clusterStore.list()).single;
    expect(career.nodeIds, containsAll(result.nodes.map((node) => node.id)));

    await graphStore.dispose();
    clusterStore.dispose();
    root.deleteSync(recursive: true);
  });

  test(
    'encrypts audio immediately and retains transcript after cleanup',
    () async {
      final root = Directory.systemTemp.createTempSync('audio_vault_test_');
      var now = DateTime.utc(2026, 7, 28);
      final storage = AudioVaultStorage.open(
        databasePath: '${root.path}/audio.sqlite3',
        keyStore: VaultKeyProvider.testing().getOrCreateMasterKey,
        clock: () => now,
      );
      final raw = Uint8List.fromList(utf8.encode('secret-wave-audio'));
      final record = await storage.sealChunk(
        bytes: raw,
        extension: 'wav',
        duration: const Duration(seconds: 2),
        retention: const Duration(hours: 1),
      );
      await storage.saveTranscript(record.id, 'Permanent private transcript');

      final databaseText = File(
        storage.databasePath,
      ).readAsStringSync(encoding: latin1);
      expect(databaseText.contains('secret-wave-audio'), isFalse);
      expect(databaseText.contains('Permanent private transcript'), isFalse);
      expect(await storage.audio(record.id), raw);

      now = now.add(const Duration(hours: 2));
      expect(await storage.cleanupExpiredAudio(), [record.id]);
      expect((await storage.get(record.id))!.hasAudio, isFalse);
      expect(
        await storage.transcript(record.id),
        'Permanent private transcript',
      );

      storage.close();
      root.deleteSync(recursive: true);
    },
  );

  test('seals live PCM chunks before final WAV assembly', () async {
    final root = Directory.systemTemp.createTempSync('audio_stream_test_');
    final storage = AudioVaultStorage.open(
      databasePath: '${root.path}/audio.sqlite3',
      keyStore: VaultKeyProvider.testing().getOrCreateMasterKey,
    );
    final session = await storage.beginStream();
    final chunk = Uint8List.fromList(utf8.encode('live-pcm-secret'));

    await storage.appendStreamChunk(id: session.id, index: 0, pcmBytes: chunk);
    expect(
      File(
        storage.databasePath,
      ).readAsStringSync(encoding: latin1).contains('live-pcm-secret'),
      isFalse,
    );
    final wav = Uint8List.fromList([
      0x52,
      0x49,
      0x46,
      0x46,
      ...List<int>.filled(40, 0),
      ...chunk,
    ]);
    final finalized = await storage.finalizeStream(
      id: session.id,
      wavBytes: wav,
      duration: const Duration(milliseconds: 1),
    );
    expect(finalized.hasAudio, isTrue);
    expect(await storage.audio(session.id), wav);

    storage.close();
    root.deleteSync(recursive: true);
  });
}
