import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/native/llama_inference_session.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_compute.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_mesh_router.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_models.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_trust_store.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'uses bounded deterministic local fallback when offload is disabled',
    () async {
      final root = await Directory.systemTemp.createTemp('hivemind_compute_');
      addTearDown(() => root.delete(recursive: true));
      final trustStore = MeshTrustStore(
        EncryptedJsonFileStore(
          file: File('${root.path}/trust.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      addTearDown(trustStore.dispose);
      final router = _FakeRouter();
      const embedding = HashedLocalEmbeddingDriver(dimensions: 16);
      final dispatcher = HivemindComputeDispatcher(
        router: router,
        identity: MeshIdentityService(),
        trustStore: trustStore,
        embeddingDriver: embedding,
        embeddingModelFingerprint: 'embedding-v1',
        llama: LlamaInferenceSession(),
        llmModelFingerprint: 'llm-v1',
      )..start();
      addTearDown(dispatcher.dispose);

      final vectors = await dispatcher.embed(['private memory']);

      expect(vectors, hasLength(1));
      expect(vectors.single, orderedEquals(embedding.embed('private memory')));
      await expectLater(
        dispatcher.embed(List.filled(65, 'too many')),
        throwsRangeError,
      );
    },
  );
}

final class _FakeRouter implements HivemindPeerRouter {
  final StreamController<HivemindPeerChannel> _channels =
      StreamController.broadcast();

  @override
  Stream<HivemindPeerChannel> get connectedChannels => _channels.stream;

  @override
  List<HivemindPeerState> get currentPeers => const [];

  @override
  HivemindGovernance get governance => const HivemindGovernance();
}
