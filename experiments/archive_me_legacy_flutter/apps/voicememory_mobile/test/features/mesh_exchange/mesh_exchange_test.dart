import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_exchange_models.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_exchange_service.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_import_validator.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('MeshExchangeService', () {
    test('ECDH peers derive the same key and open a signed envelope', () async {
      final receiver = _service('receiver');
      final sender = _service('sender');
      final invitation = await receiver.createInvitation();
      final content = sender.buildContent(
        senderName: 'Alice',
        graph: _graph(),
        selectedNodeIds: const ['node-a', 'node-b'],
      );

      final package = await sender.package(
        invitation: MeshExchangeInvitation.decode(invitation.encode()),
        content: content,
      );
      final opened = await receiver.open(package.bytes);

      expect(opened.id, content.id);
      expect(opened.senderName, 'Alice');
      expect(opened.graph.nodes.map((item) => item.id), {'node-a', 'node-b'});
      sender.dispose();
      receiver.dispose();
    });

    test('rejects signature tampering before decryption', () async {
      final receiver = _service('receiver');
      final sender = _service('sender');
      final invitation = await receiver.createInvitation();
      final content = sender.buildContent(
        senderName: 'Alice',
        graph: _graph(),
        selectedNodeIds: const ['node-a'],
      );
      final package = await sender.package(
        invitation: invitation,
        content: content,
      );
      final json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(package.bytes)) as Map,
      );
      final signature = base64Decode(json['signature'] as String);
      signature[0] ^= 1;
      json['signature'] = base64Encode(signature);

      await expectLater(
        receiver.open(Uint8List.fromList(utf8.encode(jsonEncode(json)))),
        throwsA(
          isA<MeshExchangeException>().having(
            (error) => error.message,
            'message',
            contains('signature'),
          ),
        ),
      );
      sender.dispose();
      receiver.dispose();
    });

    test('animated QR chunks reassemble safely out of order', () async {
      final receiver = _service('receiver');
      final sender = _service('sender');
      final invitation = await receiver.createInvitation();
      final package = await sender.package(
        invitation: invitation,
        content: sender.buildContent(
          senderName: 'Alice',
          graph: _graph(),
          selectedNodeIds: const ['node-a', 'node-b'],
        ),
        qrPayloadCharacters: 128,
      );
      final assembler = MeshQrAssembler();
      Uint8List? assembled;
      for (final frame in package.frames.reversed) {
        assembled = assembler.add(frame.encode()) ?? assembled;
      }

      expect(assembled, package.bytes);
      expect(assembler.progress, 1);
      sender.dispose();
      receiver.dispose();
    });
  });

  test(
    'validator quarantines conflicts in an attributed isolated branch',
    () async {
      final root = Directory.systemTemp.createTempSync('mesh_exchange_test_');
      final receiver = _service('receiver');
      final sender = _service('sender');
      final store = MeshIncomingStore.open(
        databasePath: '${root.path}/incoming.sqlite3',
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      final validator = MeshImportValidator(exchange: receiver, store: store);
      final invitation = await receiver.createInvitation();
      final package = await sender.package(
        invitation: invitation,
        content: sender.buildContent(
          senderName: 'Alice',
          graph: _graph(),
          selectedNodeIds: const ['node-a', 'node-b'],
          policy: MeshExchangePolicy.readOnce,
        ),
      );
      final local = PersonalKnowledgeGraph(nodes: [_node('node-a', 'Local')]);

      final diff = await validator.validate(
        envelope: package.bytes,
        localGraph: local,
        localPersonas: const [],
      );
      expect(diff.conflictingNodeIds, ['node-a']);
      expect(diff.newNodeIds, ['node-b']);

      final imported = await validator.approve(diff);
      expect(imported.provenance, 'Received via Mesh from Alice');
      expect(local.nodes.single.label, 'Local');
      final stored = await store.list();
      expect(stored, hasLength(1));
      expect(stored.single.content.clusters.last.title, imported.provenance);
      await expectLater(
        receiver.open(package.bytes),
        throwsA(isA<MeshExchangeException>()),
      );

      store.close();
      sender.dispose();
      receiver.dispose();
      root.deleteSync(recursive: true);
    },
  );
}

MeshExchangeService _service(String id) => MeshExchangeService(
  identity: MeshIdentityService(
    store: MemorySyncIdentityStore(),
    deviceIdProvider: () async => id,
  ),
);

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  nodes: [_node('node-a', 'Alpha'), _node('node-b', 'Beta')],
  edges: [
    GraphEdge(
      id: 'edge',
      sourceNodeId: 'node-a',
      targetNodeId: 'node-b',
      type: EdgeType.influences,
      isDirected: true,
      weight: .8,
      evidence: [
        GraphEdgeEvidence(
          entryId: 'entry-edge',
          observedAt: DateTime.utc(2026),
          confidence: .9,
          excerpt: 'Alpha influences Beta',
          startUtf16: 0,
          endUtf16: 21,
        ),
      ],
    ),
  ],
);

GraphNode _node(String id, String label) => GraphNode(
  id: id,
  type: NodeType.topic,
  label: label,
  confidence: .9,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: DateTime.utc(2026),
      confidence: .9,
      excerpt: label,
      startUtf16: 0,
      endUtf16: label.length,
    ),
  ],
);
