import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('EncryptedGraphSyncEnvelope', () {
    test('round-trips strict PBKDF2 and AES-GCM metadata', () async {
      final envelope = await _engine().encryptWithPassphrase(
        _graph(),
        'portable words',
      );

      final decoded = EncryptedGraphSyncEnvelope.decode(envelope.encode());

      expect(decoded.toJson(), envelope.toJson());
      expect(decoded.algorithm, 'AES-256-GCM');
      expect(decoded.kdf, 'PBKDF2-HMAC-SHA256');
      expect(decoded.iterations, 210000);
      expect(decoded.mode, EncryptedGraphSyncMode.portable);
      expect(base64Decode(decoded.salt), hasLength(16));
      expect(base64Decode(decoded.nonce), hasLength(12));
      expect(base64Decode(decoded.mac), hasLength(16));
    });

    test('rejects malformed, missing, and extra envelope fields', () {
      expect(
        () => EncryptedGraphSyncEnvelope.decode('not-json'),
        throwsA(isA<EncryptedGraphSyncFormatException>()),
      );
      expect(
        () => EncryptedGraphSyncEnvelope.decode('{"version":1}'),
        throwsA(isA<EncryptedGraphSyncFormatException>()),
      );
      expect(
        () => EncryptedGraphSyncEnvelope.fromJson({
          ..._validEnvelopeJson(),
          'plaintext': 'must not be accepted',
        }),
        throwsA(isA<EncryptedGraphSyncFormatException>()),
      );
    });
  });

  group('EncryptedGraphSyncEngine encryption', () {
    test('passphrase payload round-trips as portable', () async {
      final engine = _engine();

      final envelope = await engine.encryptWithPassphrase(
        _graph(),
        'correct horse battery staple',
      );
      final restored = await engine.decrypt(
        envelope,
        passphrase: 'correct horse battery staple',
      );

      expect(envelope.mode, EncryptedGraphSyncMode.portable);
      expect(restored.toJson(), _graph().toJson());
    });

    test('dedicated device seed round-trips as deviceBound', () async {
      final seeds = InMemorySyncSeedStore();
      final engine = _engine(seedStore: seeds);

      final envelope = await engine.encryptWithDeviceSeed(_graph());
      final restored = await engine.decrypt(envelope);

      expect(envelope.mode, EncryptedGraphSyncMode.deviceBound);
      expect((await seeds.readSeed()), hasLength(32));
      expect(restored.toJson(), _graph().toJson());
    });

    test('each encryption uses a different salt and nonce', () async {
      final engine = _engine();

      final first = await engine.encryptWithPassphrase(_graph(), 'same');
      final second = await engine.encryptWithPassphrase(_graph(), 'same');

      expect(first.salt, isNot(second.salt));
      expect(first.nonce, isNot(second.nonce));
      expect(first.ciphertext, isNot(second.ciphertext));
    });

    test('wrong passphrase fails with key and integrity exception', () async {
      final engine = _engine();
      final envelope = await engine.encryptWithPassphrase(_graph(), 'right');

      expect(
        () => engine.decrypt(envelope, passphrase: 'wrong'),
        throwsA(
          isA<EncryptedGraphSyncKeyException>().having(
            (error) => error,
            'is also integrity failure',
            isA<EncryptedGraphSyncIntegrityException>(),
          ),
        ),
      );
    });

    for (final field in ['ciphertext', 'mac', 'nonce']) {
      test('modified $field fails authenticated integrity', () async {
        final engine = _engine();
        final envelope = await engine.encryptWithPassphrase(_graph(), 'right');
        final json = envelope.toJson();
        json[field] = _flipBase64(json[field] as String);

        expect(
          () => engine.decrypt(
            EncryptedGraphSyncEnvelope.fromJson(json),
            passphrase: 'right',
          ),
          throwsA(isA<EncryptedGraphSyncIntegrityException>()),
        );
      });
    }

    test('modified AAD mode metadata fails authenticated integrity', () async {
      final seedStore = InMemorySyncSeedStore(seed: List.filled(32, 7));
      final engine = _engine(seedStore: seedStore);
      final envelope = await engine.encryptWithPassphrase(_graph(), 'right');
      final json = envelope.toJson();
      json['mode'] = EncryptedGraphSyncMode.deviceBound.name;

      expect(
        () => engine.decrypt(EncryptedGraphSyncEnvelope.fromJson(json)),
        throwsA(isA<EncryptedGraphSyncIntegrityException>()),
      );
    });
  });

  group('transport and restore', () {
    test(
      'transport receives ciphertext without plaintext node labels',
      () async {
        final transport = _MemoryTransport();
        final engine = _engine(transport: transport);

        await engine.exportWithPassphrase(
          graph: _graph(),
          target: EncryptedGraphSyncTarget.googleDrive,
          filename: 'graph.archiveme',
          passphrase: 'portable',
        );

        expect(transport.uploaded, isNotNull);
        expect(transport.uploaded, isNot(contains('Extremely Private Goal')));
        expect(
          EncryptedGraphSyncEnvelope.decode(transport.uploaded!).ciphertext,
          isNotEmpty,
        );
      },
    );

    test('uses truthful iCloud and Google Drive suggested paths', () async {
      final transport = _MemoryTransport();
      final engine = _engine(transport: transport);

      await engine.exportWithPassphrase(
        graph: _graph(),
        target: EncryptedGraphSyncTarget.iCloudDrive,
        filename: 'one.enc',
        passphrase: 'portable',
      );
      expect(transport.lastPath, 'Documents/ArchiveMe_Sync/one.enc');

      await engine.exportWithPassphrase(
        graph: _graph(),
        target: EncryptedGraphSyncTarget.googleDrive,
        filename: 'two.enc',
        passphrase: 'portable',
      );
      expect(transport.lastPath, 'ArchiveMe_Sync/two.enc');
    });

    test('import downloads then decrypts and validates', () async {
      final transport = _MemoryTransport();
      final engine = _engine(transport: transport);
      await engine.exportWithPassphrase(
        graph: _graph(),
        target: EncryptedGraphSyncTarget.googleDrive,
        filename: 'graph.enc',
        passphrase: 'portable',
      );

      final imported = await engine.importWithPassphrase(
        target: EncryptedGraphSyncTarget.googleDrive,
        filename: 'graph.enc',
        passphrase: 'portable',
      );

      expect(imported.toJson(), _graph().toJson());
    });

    test('failed integrity never overwrites graph store', () async {
      final directory = await Directory.systemTemp.createTemp(
        'encrypted_graph_restore_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/graph.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      final original = PersonalKnowledgeGraph(
        nodes: [
          GraphNode(
            type: NodeType.memory,
            label: 'Original',
            confidence: 1,
            evidence: [
              GraphNodeEvidence(
                entryId: 'original-entry',
                observedAt: DateTime.utc(2026, 7, 22),
                confidence: 1,
                excerpt: 'Original',
                startUtf16: 0,
                endUtf16: 8,
              ),
            ],
          ),
        ],
      );
      await graphStore.save(original);

      final transport = _MemoryTransport();
      final engine = _engine(transport: transport);
      await engine.exportWithPassphrase(
        graph: _graph(),
        target: EncryptedGraphSyncTarget.iCloudDrive,
        filename: 'restore.enc',
        passphrase: 'right',
      );
      final tampered = EncryptedGraphSyncEnvelope.decode(transport.uploaded!);
      transport.uploaded = EncryptedGraphSyncEnvelope.fromJson({
        ...tampered.toJson(),
        'mac': _flipBase64(tampered.mac),
      }).encode();

      await expectLater(
        engine.restoreWithPassphrase(
          store: graphStore,
          target: EncryptedGraphSyncTarget.iCloudDrive,
          filename: 'restore.enc',
          passphrase: 'right',
        ),
        throwsA(isA<EncryptedGraphSyncIntegrityException>()),
      );
      expect((await graphStore.load()).toJson(), original.toJson());
    });

    test('manual local transport writes only the encrypted envelope', () async {
      final directory = await Directory.systemTemp.createTemp(
        'manual_graph_sync_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final engine = _engine(
        transport: ManualLocalFileEncryptedGraphSyncTransport(directory),
      );

      await engine.exportWithPassphrase(
        graph: _graph(),
        target: EncryptedGraphSyncTarget.googleDrive,
        filename: 'manual.enc',
        passphrase: 'portable',
      );

      final file = File('${directory.path}/ArchiveMe_Sync/manual.enc');
      expect(await file.exists(), isTrue);
      expect(
        await file.readAsString(),
        isNot(contains('Extremely Private Goal')),
      );
    });

    test('unavailable production transport never claims success', () {
      final engine = _engine();

      expect(
        () => engine.exportWithPassphrase(
          graph: _graph(),
          target: EncryptedGraphSyncTarget.googleDrive,
          filename: 'graph.enc',
          passphrase: 'portable',
        ),
        throwsA(isA<EncryptedGraphSyncTransportException>()),
      );
    });
  });
}

EncryptedGraphSyncEngine _engine({
  SyncSeedStore? seedStore,
  EncryptedGraphSyncTransport? transport,
}) => EncryptedGraphSyncEngine(
  seedStore: seedStore,
  transport: transport,
  random: _SequenceRandom(),
);

PersonalKnowledgeGraph _graph() {
  final goal = GraphNode(
    type: NodeType.goal,
    label: 'Extremely Private Goal',
    confidence: 0.9,
    evidence: [
      GraphNodeEvidence(
        entryId: 'journal-private',
        observedAt: DateTime.utc(2026, 7, 23),
        confidence: 0.9,
        excerpt: 'private evidence',
        startUtf16: 0,
        endUtf16: 16,
      ),
    ],
  );
  return PersonalKnowledgeGraph(nodes: [goal]);
}

Map<String, dynamic> _validEnvelopeJson() => {
  'version': 1,
  'algorithm': 'AES-256-GCM',
  'kdf': 'PBKDF2-HMAC-SHA256',
  'mode': 'portable',
  'salt': base64Encode(List.filled(16, 1)),
  'iterations': 210000,
  'nonce': base64Encode(List.filled(12, 2)),
  'ciphertext': base64Encode([3]),
  'mac': base64Encode(List.filled(16, 4)),
};

String _flipBase64(String encoded) {
  final bytes = base64Decode(encoded);
  bytes[0] ^= 1;
  return base64Encode(bytes);
}

class _MemoryTransport implements EncryptedGraphSyncTransport {
  String? uploaded;
  String? lastPath;

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async {
    lastPath = path;
    return uploaded!;
  }

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    lastPath = path;
    uploaded = encryptedEnvelope;
  }
}

class _SequenceRandom implements Random {
  var _next = 0;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);

  @override
  int nextInt(int max) {
    final result = _next % max;
    _next++;
    return result;
  }
}
