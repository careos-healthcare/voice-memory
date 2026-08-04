import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/p2p_mesh/vault_share/vault_share.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late CryptographyVaultShareSigner signer;
  late SemanticCluster cluster;
  late PersonalKnowledgeGraph graph;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vshare_test_');
    signer = await CryptographyVaultShareSigner.create(
      signerId: 'alice-device',
      keyPair: await Ed25519().newKeyPair(),
    );
    final evidence = GraphNodeEvidence(
      entryId: 'entry-1',
      observedAt: DateTime.utc(2026, 1, 2),
      confidence: 0.9,
      excerpt: 'Alice',
      startUtf16: 0,
      endUtf16: 5,
    );
    final first = GraphNode(
      id: 'node-1',
      type: NodeType.person,
      label: 'Alice',
      confidence: 0.9,
      evidence: [evidence],
      mediaAttachments: [
        MediaAttachment(
          id: 'photo-1',
          encryptedFilePath: '/private/photo.vault',
          encryptedFileSha256: 'local-only',
          fileSize: 4,
          caption: 'A shared photo',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ],
    );
    final second = GraphNode(
      id: 'node-2',
      type: NodeType.project,
      label: 'Project',
      confidence: 1,
      origin: NodeOrigin.manual,
    );
    final edge = GraphEdge(
      id: 'edge-1',
      sourceNodeId: first.id,
      targetNodeId: second.id,
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: 1,
      origin: NodeOrigin.manual,
    );
    graph = PersonalKnowledgeGraph(nodes: [first, second], edges: [edge]);
    cluster = SemanticCluster(
      id: 'cluster-1',
      title: 'Selected',
      category: SemanticClusterCategory.project,
      nodeIds: [first.id, second.id],
      activityVelocity: 0.5,
      confidenceScore: 0.8,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('round trips a selective signed encrypted share', () async {
    final output = File('${root.path}/selected.vshare');
    final service = VaultShareService(clock: () => DateTime.utc(2026, 2, 3));
    final result = await service.export(
      output: output,
      password: VaultSharePassword('correct horse battery'),
      selection: VaultShareSelection(
        clusterIds: [cluster.id],
        includeCitationExcerpts: true,
        mediaAttachmentIds: const ['photo-1'],
      ),
      clusters: [cluster],
      graph: graph,
      signer: signer,
      biometricAuthorizer: _Biometric(true),
      mediaProvider: _MediaProvider({
        'photo-1': [1, 2, 3, 4],
      }),
    );

    final branch = await service.import(
      input: output,
      password: VaultSharePassword('correct horse battery'),
    );

    expect(result.nodeCount, 2);
    expect(result.edgeCount, 1);
    expect(branch.shareId, result.shareId);
    expect(branch.clusters.single.id, cluster.id);
    expect(branch.graph.nodes, hasLength(2));
    expect(branch.graph.edges, hasLength(1));
    expect(branch.graph.nodes.first.evidence.single.excerpt, 'Alice');
    expect(branch.encryptedMedia['photo-1'], [1, 2, 3, 4]);
    expect(branch.attribution.signerId, 'alice-device');
    expect(branch.attribution.status, VaultShareSignerStatus.unknown);
    expect(await output.readAsString(), isNot(contains('Alice')));
    expect(await output.readAsString(), isNot(contains('/private/')));
  });

  test('requires biometric authorization before export', () async {
    await expectLater(
      VaultShareService().export(
        output: File('${root.path}/denied.vshare'),
        password: VaultSharePassword('correct horse battery'),
        selection: VaultShareSelection(clusterIds: [cluster.id]),
        clusters: [cluster],
        graph: graph,
        signer: signer,
        biometricAuthorizer: _Biometric(false),
      ),
      throwsA(isA<VaultShareAuthorizationException>()),
    );
  });

  test('rejects signature tampering before password decryption', () async {
    final output = File('${root.path}/tampered.vshare');
    final service = VaultShareService();
    await service.export(
      output: output,
      password: VaultSharePassword('correct horse battery'),
      selection: VaultShareSelection(clusterIds: [cluster.id]),
      clusters: [cluster],
      graph: graph,
      signer: signer,
      biometricAuthorizer: _Biometric(true),
    );
    final envelope = Map<String, dynamic>.from(
      jsonDecode(await output.readAsString()) as Map,
    );
    final signature = base64Decode(envelope['signature'] as String);
    signature[0] ^= 1;
    envelope['signature'] = base64Encode(signature);
    await output.writeAsString(jsonEncode(envelope));

    await expectLater(
      service.import(
        input: output,
        password: VaultSharePassword('wrong password still long'),
      ),
      throwsA(isA<VaultShareSignatureException>()),
    );
  });

  test('stores imported branches encrypted and immutably', () async {
    final encryptedFile = File('${root.path}/shared_branches.enc');
    final storage = EncryptedJsonFileStore(
      file: encryptedFile,
      keyStore: InMemoryPrivateDataEncryptionKeyStore(
        seedKey: List<int>.generate(32, (index) => index),
      ),
    );
    final store = SharedVaultBranchStore(storage: storage);
    final branch = SharedVaultBranch(
      shareId: 'share-1',
      createdAt: DateTime.utc(2026, 1, 1),
      importedAt: DateTime.utc(2026, 1, 2),
      attribution: const VaultShareSignerAttribution(
        signerId: 'unknown-device',
        publicKeyFingerprint: 'fingerprint',
        status: VaultShareSignerStatus.unknown,
      ),
      clusters: [cluster],
      graph: graph,
      encryptedMedia: {
        'photo-1': Uint8List.fromList([9, 8, 7]),
      },
    );

    await store.add(branch);

    expect((await store.list()).single.shareId, 'share-1');
    expect(
      await encryptedFile.readAsString(),
      isNot(contains('unknown-device')),
    );
    await expectLater(
      store.add(branch),
      throwsA(isA<VaultShareValidationException>()),
    );
  });
}

final class _Biometric implements VaultShareBiometricAuthorizer {
  const _Biometric(this.allowed);
  final bool allowed;

  @override
  Future<bool> authorizeVaultShare(VaultShareSelection selection) async =>
      allowed;
}

final class _MediaProvider implements VaultShareMediaProvider {
  const _MediaProvider(this.values);
  final Map<String, List<int>> values;

  @override
  Future<Uint8List> readPortableMedia(String attachmentId) async =>
      Uint8List.fromList(values[attachmentId]!);
}
