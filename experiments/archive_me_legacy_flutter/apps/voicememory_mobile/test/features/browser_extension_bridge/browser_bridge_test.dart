import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/browser_extension_bridge/browser_bridge_models.dart';
import 'package:voicememory_mobile/features/browser_extension_bridge/clipper_ingestion_engine.dart';
import 'package:voicememory_mobile/features/browser_extension_bridge/vault_bridge_server.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_chunker.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_graph_mapper.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_parser_service.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_semantic_index.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/browser_bridge_vault.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('QR handshake trusts a signed extension for only 60 seconds', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final invitation = await harness.server.createPairingInvitation();

    final paired = await harness.server.pair({
      'token': invitation.token,
      'pin': invitation.pin,
      'name': 'Firefox test clipper',
      'publicKey': base64Encode(publicKey.bytes),
    });
    final id = paired['extensionId']! as String;
    final timestamp = harness.now.toIso8601String();
    const nonce = 'unique-authentication-nonce';
    final signature = await Ed25519().sign(
      utf8.encode('$id|$timestamp|$nonce'),
      keyPair: keyPair,
    );
    final authenticated = await harness.server.authenticate({
      'extensionId': id,
      'timestamp': timestamp,
      'nonce': nonce,
      'signature': base64Encode(signature.bytes),
    });

    expect(authenticated.id, id);
    expect(harness.server.activeInvitation, isNull);
    await expectLater(
      harness.server.pair({
        'token': invitation.token,
        'pin': invitation.pin,
        'name': 'Replay',
        'publicKey': base64Encode(publicKey.bytes),
      }),
      throwsA(isA<VaultBridgeAuthenticationException>()),
    );
  });

  test(
    'decrypts authenticated AES-GCM clip payloads and rejects tampering',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final extension = await harness.trustedExtension();
      final payload = WebClipPayload(
        url: Uri.parse('https://example.com/article'),
        title: 'Private article',
        content: '<p>Local knowledge</p>',
        contentType: 'text/html',
        capturedAt: harness.now,
      );
      final nonce = Uint8List.fromList(List.generate(12, (index) => index));
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(payload.toJson())),
        secretKey: SecretKey(extension.sessionKey),
        nonce: nonce,
        aad: utf8.encode('browser-clip-v1|${extension.id}'),
      );
      final frame = {
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      };

      expect(
        (await harness.server.decryptPayload(extension, frame)).title,
        'Private article',
      );
      frame['mac'] = base64Encode(List<int>.filled(16, 0));
      await expectLater(
        harness.server.decryptPayload(extension, frame),
        throwsA(isA<VaultBridgeAuthenticationException>()),
      );
    },
  );

  test('unauthorized local WebSocket is rejected before ingestion', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.server.start();
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${harness.server.port}/bridge',
    );
    socket.add(jsonEncode({'type': 'hello', 'extensionId': 'unknown'}));
    final response = jsonDecode(await socket.first as String) as Map;
    expect(response['type'], 'error');
  });

  test(
    'sanitizes, chunks, encrypts and vectorizes web clips locally',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final extension = await harness.trustedExtension();
      final result = await harness.ingestion.ingest(
        extensionId: extension.id,
        payload: WebClipPayload(
          url: Uri.parse('https://example.com/private'),
          title: 'Research',
          content: '''
          <html><body>
          <script>sendTracker(secret)</script>
          <img src="https://tracker.example/pixel" width="1" height="1">
          <h1>Useful heading</h1>
          <p>A private local-first article with semantic knowledge.</p>
          </body></html>
        ''',
          contentType: 'text/html',
          capturedAt: harness.now,
          highlights: const ['Semantic knowledge'],
        ),
      );

      final stored = await harness.vault.clip(result.clipId);
      final vectors = await harness.semanticIndex.records();
      expect(result.chunkCount, greaterThan(0));
      expect(
        vectors.where((item) => item.documentId == result.clipId),
        isNotEmpty,
      );
      expect(stored!.payload.content, isNot(contains('sendTracker')));
      expect(stored.payload.content, isNot(contains('tracker.example')));
      expect(stored.payload.content, contains('Saved highlights'));
      expect(
        latin1
            .decode(File(harness.vault.databasePath).readAsBytesSync())
            .contains('Useful heading'),
        isFalse,
      );
    },
  );
}

final class _Harness {
  _Harness({
    required this.root,
    required this.vault,
    required this.semanticIndex,
    required this.overlay,
    required this.graphStore,
    required this.clusterStore,
    required this.ingestion,
    required this.server,
    required this.now,
  });

  final Directory root;
  final BrowserBridgeVault vault;
  final DocumentSemanticIndex semanticIndex;
  final DocumentGraphOverlayStore overlay;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final ClipperIngestionEngine ingestion;
  final VaultBridgeServer server;
  final DateTime now;

  static Future<_Harness> create() async {
    final root = Directory.systemTemp.createTempSync('browser_bridge_test_');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    final vault = BrowserBridgeVault.open(
      databasePath: '${root.path}/bridge.sqlite3',
      keyStore: keyStore,
    );
    final semanticIndex = DocumentSemanticIndex(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/vectors.enc'),
        keyStore: keyStore,
      ),
      vectorStore: await SqliteVecVectorStore.open(
        databasePath: '${root.path}/vectors.sqlite3',
        dimensions: 384,
      ),
    );
    final overlay = DocumentGraphOverlayStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/overlay.enc'),
        keyStore: keyStore,
      ),
    );
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: keyStore,
      ),
    );
    final clusterStore = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/clusters.enc'),
        keyStore: keyStore,
      ),
    );
    final ingestion = ClipperIngestionEngine(
      vault: vault,
      parser: DocumentParserService(),
      chunker: const DocumentChunker(maxTokens: 20, overlapTokens: 2),
      semanticIndex: semanticIndex,
      mapper: DocumentGraphMapper(
        semanticIndex: semanticIndex,
        overlayStore: overlay,
      ),
      graphStore: graphStore,
      clusterStore: clusterStore,
      autoTaggingEnabled: () async => false,
      rejectedNodeIds: () async => const {},
    );
    final now = DateTime.utc(2026, 7, 28, 12);
    final server = VaultBridgeServer(
      vault: vault,
      ingestion: ingestion,
      clock: () => now,
      preferredPort: 0,
    );
    return _Harness(
      root: root,
      vault: vault,
      semanticIndex: semanticIndex,
      overlay: overlay,
      graphStore: graphStore,
      clusterStore: clusterStore,
      ingestion: ingestion,
      server: server,
      now: now,
    );
  }

  Future<TrustedBrowserExtension> trustedExtension() async {
    final extension = TrustedBrowserExtension(
      id: 'trusted-extension',
      name: 'Test browser',
      publicKey: Uint8List(32),
      sessionKey: Uint8List.fromList(List.generate(32, (index) => index)),
      pairedAt: now,
      lastSeenAt: now,
    );
    await vault.trust(extension);
    return extension;
  }

  Future<void> dispose() async {
    await server.dispose();
    await overlay.dispose();
    await semanticIndex.dispose();
    await graphStore.dispose();
    clusterStore.dispose();
    vault.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
