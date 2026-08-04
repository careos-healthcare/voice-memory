// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../storage/encrypted_json_file_store.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import 'vault_share_models.dart';

/// Encrypted append-only storage for imported shares.
///
/// There is deliberately no update, merge, or delete API: imported branches
/// remain immutable and separate from the recipient's personal vault.
final class SharedVaultBranchStore {
  SharedVaultBranchStore({required EncryptedJsonFileStore storage})
    : _storage = storage;

  final EncryptedJsonFileStore _storage;
  Future<void> _tail = Future<void>.value();

  Future<List<SharedVaultBranch>> list() => _serialized(_read);

  Future<SharedVaultBranch?> get(String shareId) => _serialized(() async {
    for (final branch in await _read()) {
      if (branch.shareId == shareId) return branch;
    }
    return null;
  });

  Future<void> add(SharedVaultBranch branch) => _serialized(() async {
    final existing = await _read();
    if (existing.any((item) => item.shareId == branch.shareId)) {
      throw VaultShareValidationException(
        'Shared vault branch already exists: ${branch.shareId}.',
      );
    }
    await _storage.writeJson({
      'schemaVersion': 1,
      'branches': [...existing, branch].map(_toJson).toList(),
    });
  });

  Future<List<SharedVaultBranch>> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) return const [];
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw['branches'] is! List ||
        raw.keys.any((key) => key != 'schemaVersion' && key != 'branches')) {
      throw const VaultShareValidationException(
        'Invalid shared vault branch store.',
      );
    }
    final ids = <String>{};
    final branches = <SharedVaultBranch>[];
    for (final item in raw['branches'] as List) {
      if (item is! Map) {
        throw const VaultShareValidationException(
          'Invalid shared vault branch row.',
        );
      }
      final branch = _fromJson(Map<String, dynamic>.from(item));
      if (!ids.add(branch.shareId)) {
        throw const VaultShareValidationException(
          'Duplicate shared vault branch.',
        );
      }
      branches.add(branch);
    }
    branches.sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return UnmodifiableListView(branches);
  }

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

Map<String, dynamic> _toJson(SharedVaultBranch branch) => {
  'shareId': branch.shareId,
  'createdAt': branch.createdAt.toIso8601String(),
  'importedAt': branch.importedAt.toIso8601String(),
  'attribution': {
    'signerId': branch.attribution.signerId,
    'publicKeyFingerprint': branch.attribution.publicKeyFingerprint,
    'status': branch.attribution.status.name,
  },
  'clusters': branch.clusters.map((item) => item.toPortableJson()).toList(),
  'graph': {
    'schemaVersion': 1,
    'nodes': branch.graph.nodes.map((item) => item.toJson()).toList(),
    'edges': branch.graph.edges.map((item) => item.toJson()).toList(),
  },
  'encryptedMedia': {
    for (final entry in branch.encryptedMedia.entries)
      entry.key: base64Encode(entry.value),
  },
};

SharedVaultBranch _fromJson(Map<String, dynamic> json) {
  const fields = {
    'shareId',
    'createdAt',
    'importedAt',
    'attribution',
    'clusters',
    'graph',
    'encryptedMedia',
  };
  if (json.keys.length != fields.length ||
      !json.keys.toSet().containsAll(fields) ||
      json['shareId'] is! String ||
      json['createdAt'] is! String ||
      json['importedAt'] is! String ||
      json['attribution'] is! Map ||
      json['clusters'] is! List ||
      json['graph'] is! Map ||
      json['encryptedMedia'] is! Map) {
    throw const VaultShareValidationException('Invalid shared vault branch.');
  }
  final createdAt = DateTime.tryParse(json['createdAt'] as String);
  final importedAt = DateTime.tryParse(json['importedAt'] as String);
  if ((json['shareId'] as String).isEmpty ||
      createdAt == null ||
      importedAt == null) {
    throw const VaultShareValidationException(
      'Invalid shared vault branch metadata.',
    );
  }
  final attributionJson = Map<String, dynamic>.from(json['attribution'] as Map);
  const attributionFields = {'signerId', 'publicKeyFingerprint', 'status'};
  if (attributionJson.keys.length != attributionFields.length ||
      !attributionJson.keys.toSet().containsAll(attributionFields) ||
      attributionJson['signerId'] is! String ||
      attributionJson['publicKeyFingerprint'] is! String ||
      attributionJson['status'] is! String) {
    throw const VaultShareValidationException('Invalid signer attribution.');
  }
  final status = VaultShareSignerStatus.values
      .where((item) => item.name == attributionJson['status'])
      .firstOrNull;
  if (status == null) {
    throw const VaultShareValidationException(
      'Invalid signer attribution status.',
    );
  }
  final clusters = (json['clusters'] as List).map((item) {
    if (item is! Map) throw const FormatException('Invalid cluster.');
    return SemanticCluster.fromJson(Map<String, dynamic>.from(item));
  }).toList();
  final graphJson = Map<String, dynamic>.from(json['graph'] as Map);
  if (graphJson['schemaVersion'] != 1 ||
      graphJson['nodes'] is! List ||
      graphJson['edges'] is! List) {
    throw const VaultShareValidationException('Invalid shared graph.');
  }
  final nodes = (graphJson['nodes'] as List).map((item) {
    if (item is! Map) throw const FormatException('Invalid graph node.');
    return GraphNode.fromJson(Map<String, dynamic>.from(item));
  }).toList();
  final edges = (graphJson['edges'] as List).map((item) {
    if (item is! Map) throw const FormatException('Invalid graph edge.');
    return GraphEdge.fromJson(Map<String, dynamic>.from(item));
  }).toList();
  final media = <String, Uint8List>{};
  for (final entry in (json['encryptedMedia'] as Map).entries) {
    if (entry.key is! String || entry.value is! String) {
      throw const VaultShareValidationException('Invalid branch media.');
    }
    final bytes = base64Decode(entry.value as String);
    if (base64Encode(bytes) != entry.value) {
      throw const VaultShareValidationException(
        'Branch media is not canonical base64.',
      );
    }
    media[entry.key as String] = Uint8List.fromList(bytes);
  }
  return SharedVaultBranch(
    shareId: json['shareId'] as String,
    createdAt: createdAt,
    importedAt: importedAt,
    attribution: VaultShareSignerAttribution(
      signerId: attributionJson['signerId'] as String,
      publicKeyFingerprint: attributionJson['publicKeyFingerprint'] as String,
      status: status,
    ),
    clusters: clusters,
    graph: PersonalKnowledgeGraph(schemaVersion: 2, nodes: nodes, edges: edges),
    encryptedMedia: media,
  );
}
