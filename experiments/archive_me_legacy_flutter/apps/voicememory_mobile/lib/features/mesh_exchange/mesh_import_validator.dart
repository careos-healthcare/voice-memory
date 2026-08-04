import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../cognitive_council/council_persona.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'mesh_exchange_models.dart';
import 'mesh_exchange_service.dart';

final class MeshImportDiff {
  MeshImportDiff({
    required this.content,
    required this.signerFingerprint,
    required Iterable<String> newNodeIds,
    required Iterable<String> conflictingNodeIds,
    required Iterable<String> newPersonaIds,
    required Iterable<String> conflictingPersonaIds,
  }) : newNodeIds = UnmodifiableListView(newNodeIds),
       conflictingNodeIds = UnmodifiableListView(conflictingNodeIds),
       newPersonaIds = UnmodifiableListView(newPersonaIds),
       conflictingPersonaIds = UnmodifiableListView(conflictingPersonaIds);

  final MeshExchangeContent content;
  final String signerFingerprint;
  final List<String> newNodeIds;
  final List<String> conflictingNodeIds;
  final List<String> newPersonaIds;
  final List<String> conflictingPersonaIds;

  int get nodeCount => content.graph.nodes.length;
  int get edgeCount => content.graph.edges.length;
  int get personaCount => content.personas.length;
  int get fragmentCount => content.journalFragments.length;
  bool get hasConflicts =>
      conflictingNodeIds.isNotEmpty || conflictingPersonaIds.isNotEmpty;
  String get provenance => 'Received via Mesh from ${content.senderName}';
}

final class MeshIncomingBundle {
  const MeshIncomingBundle({
    required this.content,
    required this.provenance,
    required this.signerFingerprint,
    required this.importedAt,
  });

  final MeshExchangeContent content;
  final String provenance;
  final String signerFingerprint;
  final DateTime importedAt;
}

/// Append-only encrypted SQLite quarantine for peer data.
///
/// It intentionally exposes no update/upsert operation: conflicting node and
/// persona IDs remain in this isolated branch until a separate, explicit
/// adoption flow is implemented.
final class MeshIncomingStore {
  MeshIncomingStore._(this._database, this.databasePath, this._keyStore);

  static MeshIncomingStore open({
    required String databasePath,
    required PrivateDataEncryptionKeyStore keyStore,
  }) {
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA secure_delete = ON')
      ..execute('''
        CREATE TABLE IF NOT EXISTS mesh_incoming (
          id TEXT PRIMARY KEY,
          ciphertext BLOB NOT NULL,
          nonce BLOB NOT NULL,
          mac BLOB NOT NULL,
          imported_at INTEGER NOT NULL
        )
      ''');
    return MeshIncomingStore._(database, databasePath, keyStore);
  }

  final Database _database;
  final String databasePath;
  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _cipher = AesGcm.with256bits();
  final Random _random = Random.secure();
  bool _closed = false;

  Future<void> add(MeshIncomingBundle bundle) async {
    _ensureOpen();
    final clear = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'content': bundle.content.toJson(),
          'provenance': bundle.provenance,
          'signerFingerprint': bundle.signerFingerprint,
          'importedAt': bundle.importedAt.toUtc().toIso8601String(),
        }),
      ),
    );
    final nonce = Uint8List.fromList(
      List.generate(12, (_) => _random.nextInt(256)),
    );
    try {
      final box = await _cipher.encrypt(
        clear,
        secretKey: SecretKey(await _key()),
        nonce: nonce,
        aad: utf8.encode('ArchiveMe.MeshIncoming.v1|${bundle.content.id}'),
      );
      _database.execute(
        'INSERT INTO mesh_incoming '
        '(id, ciphertext, nonce, mac, imported_at) VALUES (?, ?, ?, ?, ?)',
        [
          bundle.content.id,
          Uint8List.fromList(box.cipherText),
          nonce,
          Uint8List.fromList(box.mac.bytes),
          bundle.importedAt.millisecondsSinceEpoch,
        ],
      );
    } on SqliteException {
      throw const MeshExchangeException(
        'This Mesh Exchange package was already imported.',
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<List<MeshIncomingBundle>> list() async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, ciphertext, nonce, mac FROM mesh_incoming '
      'ORDER BY imported_at DESC',
    );
    final result = <MeshIncomingBundle>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final clear = await _cipher.decrypt(
        SecretBox(
          row['ciphertext'] as Uint8List,
          nonce: row['nonce'] as Uint8List,
          mac: Mac(row['mac'] as Uint8List),
        ),
        secretKey: SecretKey(await _key()),
        aad: utf8.encode('ArchiveMe.MeshIncoming.v1|$id'),
      );
      final json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(clear)) as Map,
      );
      result.add(
        MeshIncomingBundle(
          content: MeshExchangeContent.fromJson(
            Map<String, dynamic>.from(json['content'] as Map),
          ),
          provenance: json['provenance'] as String,
          signerFingerprint: json['signerFingerprint'] as String,
          importedAt: DateTime.parse(json['importedAt'] as String),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  void checkpoint() => _database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  void clear() => _database.execute('DELETE FROM mesh_incoming');
  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Mesh incoming store is closed.');
  }

  Future<List<int>> _key() async {
    final existing = await _keyStore.readKeyBytes();
    if (existing != null && existing.length == 32) return existing;
    final generated = List<int>.generate(32, (_) => _random.nextInt(256));
    await _keyStore.writeKeyBytes(generated);
    return generated;
  }
}

final class MeshImportValidator {
  const MeshImportValidator({
    required this.exchange,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MeshExchangeService exchange;
  final MeshIncomingStore store;
  final DateTime Function() _clock;

  Future<MeshImportDiff> validate({
    required Uint8List envelope,
    required PersonalKnowledgeGraph localGraph,
    required Iterable<CouncilPersona> localPersonas,
  }) async {
    final content = await exchange.open(envelope);
    final localNodeIds = localGraph.nodes.map((item) => item.id).toSet();
    final localPersonaIds = localPersonas.map((item) => item.id).toSet();
    final incomingNodeIds = content.graph.nodes.map((item) => item.id).toSet();
    final incomingPersonaIds = content.personas.map((item) => item.id).toSet();
    return MeshImportDiff(
      content: content,
      signerFingerprint: _fingerprint(envelope),
      newNodeIds: incomingNodeIds.difference(localNodeIds),
      conflictingNodeIds: incomingNodeIds.intersection(localNodeIds),
      newPersonaIds: incomingPersonaIds.difference(localPersonaIds),
      conflictingPersonaIds: incomingPersonaIds.intersection(localPersonaIds),
    );
  }

  Future<MeshIncomingBundle> approve(MeshImportDiff diff) async {
    final provenance = diff.provenance;
    final provenanceCluster = SemanticCluster(
      id: 'mesh:${diff.content.id}',
      title: provenance,
      category: SemanticClusterCategory.peopleNetwork,
      nodeIds: diff.content.graph.nodes.map((item) => item.id),
      activityVelocity: 0,
      confidenceScore: 1,
      summary: 'Cryptographically verified, isolated incoming branch.',
      updatedAt: _clock(),
      userEdited: false,
    );
    final isolated = MeshExchangeContent(
      id: diff.content.id,
      senderName: diff.content.senderName,
      graph: diff.content.graph,
      clusters: [...diff.content.clusters, provenanceCluster],
      personas: diff.content.personas,
      journalFragments: diff.content.journalFragments,
      policy: diff.content.policy,
      createdAt: diff.content.createdAt,
      destructAt: diff.content.destructAt,
    );
    final bundle = MeshIncomingBundle(
      content: isolated,
      provenance: provenance,
      signerFingerprint: diff.signerFingerprint,
      importedAt: _clock().toUtc(),
    );
    await store.add(bundle);
    exchange.markConsumed(diff.content);
    return bundle;
  }

  String _fingerprint(Uint8List envelope) {
    final json = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(envelope)) as Map,
    );
    final key = base64Decode(json['senderIdentityKey'] as String);
    // Display-only fingerprint. Signature verification occurs in exchange.open.
    return base64UrlEncode(
      hashes.sha256.convert(key).bytes.sublist(0, 16),
    ).replaceAll('=', '');
  }
}
