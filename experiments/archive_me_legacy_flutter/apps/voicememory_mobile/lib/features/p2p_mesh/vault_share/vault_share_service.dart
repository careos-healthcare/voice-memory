import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../export_backup/vault_backup_models.dart';
import '../../export_backup/vault_format.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import 'shared_vault_branch_store.dart';
import 'vault_share_format.dart';
import 'vault_share_models.dart';

final class VaultShareExportResult {
  const VaultShareExportResult({
    required this.output,
    required this.shareId,
    required this.nodeCount,
    required this.edgeCount,
    required this.mediaCount,
  });

  final File output;
  final String shareId;
  final int nodeCount;
  final int edgeCount;
  final int mediaCount;
}

final class VaultShareService {
  VaultShareService({
    this.limits = const VaultShareLimits(),
    VaultZipCodec? zipCodec,
    VaultShareCryptography? cryptography,
    VaultShareSignatureVerifier? signatureVerifier,
    DateTime Function()? clock,
  }) : _zipCodec = zipCodec ?? const ArchiveVaultZipCodec(),
       _cryptography = cryptography ?? VaultShareCryptography(),
       _signatureVerifier =
           signatureVerifier ?? CryptographyVaultShareVerifier(),
       _clock = clock ?? DateTime.now;

  final VaultShareLimits limits;
  final VaultZipCodec _zipCodec;
  final VaultShareCryptography _cryptography;
  final VaultShareSignatureVerifier _signatureVerifier;
  final DateTime Function() _clock;

  Future<VaultShareExportResult> export({
    required File output,
    required VaultSharePassword password,
    required VaultShareSelection selection,
    required Iterable<SemanticCluster> clusters,
    required PersonalKnowledgeGraph graph,
    required VaultShareSigner signer,
    required VaultShareBiometricAuthorizer biometricAuthorizer,
    VaultShareMediaProvider? mediaProvider,
  }) async {
    if (!output.path.toLowerCase().endsWith('.vshare')) {
      throw const VaultShareValidationException(
        'Vault shares must use the .vshare extension.',
      );
    }
    if (!await biometricAuthorizer.authorizeVaultShare(selection)) {
      throw const VaultShareAuthorizationException();
    }
    await _rejectLink(output);

    final selectedClusters =
        clusters
            .where((cluster) => selection.clusterIds.contains(cluster.id))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (selectedClusters.length != selection.clusterIds.length) {
      throw const VaultShareValidationException(
        'A selected semantic cluster does not exist.',
      );
    }
    if (selectedClusters.length > limits.maxClusters) {
      throw const VaultShareValidationException('Too many selected clusters.');
    }

    final selectedNodeIds = selectedClusters
        .expand((cluster) => cluster.nodeIds)
        .toSet();
    final nodes =
        graph.nodes.where((node) => selectedNodeIds.contains(node.id)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (nodes.length != selectedNodeIds.length) {
      throw const VaultShareValidationException(
        'A selected cluster references a missing graph node.',
      );
    }
    final edges =
        graph.edges
            .where(
              (edge) =>
                  selectedNodeIds.contains(edge.sourceNodeId) &&
                  selectedNodeIds.contains(edge.targetNodeId),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (nodes.length > limits.maxNodes || edges.length > limits.maxEdges) {
      throw const VaultShareValidationException(
        'Selected graph exceeds share limits.',
      );
    }

    final attachments = {
      for (final node in nodes)
        for (final attachment in node.mediaAttachments)
          if (selection.mediaAttachmentIds.contains(attachment.id))
            attachment.id: attachment,
    };
    if (attachments.length != selection.mediaAttachmentIds.length) {
      throw const VaultShareValidationException(
        'An opted-in media attachment is not part of the selection.',
      );
    }
    if (attachments.length > limits.maxMedia) {
      throw const VaultShareValidationException('Too many media attachments.');
    }
    if (attachments.isNotEmpty && mediaProvider == null) {
      throw const VaultShareValidationException(
        'A media provider is required for opted-in media.',
      );
    }

    final now = _clock().toUtc();
    final shareId = vaultShareSha256(
      utf8.encode(
        '${signer.signerId}|${now.toIso8601String()}|'
        '${selectedClusters.map((item) => item.id).join(',')}',
      ),
    );
    final data = SplayTreeMap<String, Uint8List>();
    data[vaultShareClustersPath] = _jsonBytes(
      selectedClusters.map((cluster) => cluster.toPortableJson()).toList(),
    );
    data[vaultShareGraphPath] = _jsonBytes({
      'schemaVersion': 1,
      'nodes': nodes
          .map(
            (node) => _exportNode(
              node,
              includeCitations: selection.includeCitationExcerpts,
              includedMediaIds: attachments.keys.toSet(),
            ),
          )
          .toList(),
      'edges': edges
          .map(
            (edge) => _exportEdge(
              edge,
              includeCitations: selection.includeCitationExcerpts,
            ),
          )
          .toList(),
    });
    for (final id in attachments.keys.toList()..sort()) {
      final bytes = await mediaProvider!.readPortableMedia(id);
      if (bytes.length > limits.maxEntryBytes) {
        throw VaultShareValidationException(
          'Media attachment exceeds its size limit: $id.',
        );
      }
      data[_mediaPath(id)] = Uint8List.fromList(bytes);
    }
    _validateDataLimits(data);

    final entries = [
      for (final entry in data.entries)
        VaultShareManifestEntry(
          path: entry.key,
          size: entry.value.length,
          sha256: vaultShareSha256(entry.value),
        ),
    ];
    final manifest = VaultShareManifest(
      shareId: shareId,
      createdAt: now,
      signerId: signer.signerId,
      includesCitationExcerpts: selection.includeCitationExcerpts,
      clusterIds: selectedClusters.map((item) => item.id),
      mediaAttachmentIds: attachments.keys.toList()..sort(),
      entries: entries,
    );
    final archiveEntries = SplayTreeMap<String, Uint8List>.from(data)
      ..[vaultShareManifestPath] = manifest.toBytes();
    Uint8List? archive;
    Uint8List? envelopeBytes;
    final temporary = File(
      '${output.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      archive = _zipCodec.encode(UnmodifiableMapView(archiveEntries));
      if (archive.length > limits.maxTotalBytes) {
        throw const VaultShareValidationException(
          'Encoded share exceeds its size limit.',
        );
      }
      final envelope = await _cryptography.encryptAndSign(
        plaintext: archive,
        password: password,
        signer: signer,
      );
      envelopeBytes = envelope.toBytes();
      if (envelopeBytes.length > limits.maxEnvelopeBytes) {
        throw const VaultShareValidationException(
          'Encrypted share exceeds its size limit.',
        );
      }
      await output.parent.create(recursive: true);
      await temporary.writeAsBytes(envelopeBytes, flush: true);
      await temporary.rename(output.path);
      return VaultShareExportResult(
        output: output,
        shareId: shareId,
        nodeCount: nodes.length,
        edgeCount: edges.length,
        mediaCount: attachments.length,
      );
    } on VaultShareException {
      await _deleteTemporary(temporary);
      rethrow;
    } on Object catch (error) {
      await _deleteTemporary(temporary);
      throw VaultShareValidationException('Vault share export failed: $error');
    } finally {
      _wipeAll(archiveEntries.values);
      _wipe(archive);
      _wipe(envelopeBytes);
    }
  }

  Future<SharedVaultBranch> import({
    required File input,
    required VaultSharePassword password,
    VaultShareSignerTrust? signerTrust,
    SharedVaultBranchStore? branchStore,
  }) async {
    if (!input.path.toLowerCase().endsWith('.vshare')) {
      throw const VaultShareValidationException(
        'Vault shares must use the .vshare extension.',
      );
    }
    if (await FileSystemEntity.type(input.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VaultShareValidationException(
        'Vault share input must be a regular file.',
      );
    }
    final stat = await input.stat();
    if (stat.size > limits.maxEnvelopeBytes) {
      throw const VaultShareValidationException(
        'Share envelope exceeds its size limit.',
      );
    }
    final envelopeBytes = Uint8List.fromList(await input.readAsBytes());
    Uint8List? archive;
    Map<String, Uint8List>? files;
    try {
      final envelope = VaultShareEnvelope.fromBytes(
        envelopeBytes,
        limits: limits,
      );
      final signatureValid = await _signatureVerifier.verify(
        message: envelope.signingBytes(),
        signature: envelope.signature,
        publicKeyBytes: envelope.signerPublicKey,
      );
      if (!signatureValid) throw const VaultShareSignatureException();
      archive = await _cryptography.decrypt(envelope, password);
      files = _zipCodec.decode(
        archive,
        VaultBackupLimits(
          maxEntries: limits.maxClusters + limits.maxMedia + 3,
          maxEntryBytes: limits.maxEntryBytes,
          maxTotalBytes: limits.maxTotalBytes,
          maxEnvelopeBytes: limits.maxEnvelopeBytes,
        ),
      );
      for (final path in files.keys) {
        validateVaultSharePath(path);
      }
      final manifestBytes = files.remove(vaultShareManifestPath);
      if (manifestBytes == null) {
        throw const VaultShareValidationException('Share manifest is missing.');
      }
      final manifest = VaultShareManifest.fromBytes(manifestBytes);
      if (manifest.signerId != envelope.signerId) {
        throw const VaultShareValidationException(
          'Envelope and manifest signer IDs differ.',
        );
      }
      _validateManifestFiles(manifest, files);
      if (manifest.clusterIds.length > limits.maxClusters ||
          manifest.mediaAttachmentIds.length > limits.maxMedia) {
        throw const VaultShareValidationException(
          'Share manifest exceeds selection limits.',
        );
      }

      final clusters = _parseClusters(files[vaultShareClustersPath]!);
      if (clusters.length != manifest.clusterIds.length ||
          clusters
              .map((item) => item.id)
              .toSet()
              .difference(manifest.clusterIds.toSet())
              .isNotEmpty) {
        throw const VaultShareValidationException(
          'Manifest cluster selection does not match its data.',
        );
      }
      final graph = _parseGraph(files[vaultShareGraphPath]!);
      _validateGraph(clusters, graph);
      final media = <String, Uint8List>{};
      for (final id in manifest.mediaAttachmentIds) {
        final bytes = files[_mediaPath(id)];
        if (bytes == null) {
          throw VaultShareValidationException(
            'Opted-in media is missing: $id.',
          );
        }
        media[id] = Uint8List.fromList(bytes);
      }
      final trusted =
          signerTrust?.isTrusted(
            signerId: envelope.signerId,
            publicKeyBytes: envelope.signerPublicKey,
          ) ??
          false;
      final branch = SharedVaultBranch(
        shareId: manifest.shareId,
        createdAt: manifest.createdAt,
        importedAt: _clock().toUtc(),
        attribution: VaultShareSignerAttribution(
          signerId: envelope.signerId,
          publicKeyFingerprint: vaultSharePublicKeyFingerprint(
            envelope.signerPublicKey,
          ),
          status: trusted
              ? VaultShareSignerStatus.trusted
              : VaultShareSignerStatus.unknown,
        ),
        clusters: clusters,
        graph: graph,
        encryptedMedia: media,
      );
      await branchStore?.add(branch);
      return branch;
    } on VaultShareException {
      rethrow;
    } on Object catch (error) {
      throw VaultShareValidationException('Vault share import failed: $error');
    } finally {
      _wipe(envelopeBytes);
      _wipe(archive);
      if (files != null) _wipeAll(files.values);
    }
  }

  void _validateDataLimits(Map<String, Uint8List> data) {
    var total = 0;
    for (final entry in data.entries) {
      validateVaultSharePath(entry.key);
      if (entry.value.length > limits.maxEntryBytes) {
        throw VaultShareValidationException(
          'Share entry exceeds its size limit: ${entry.key}.',
        );
      }
      total += entry.value.length;
      if (total > limits.maxTotalBytes) {
        throw const VaultShareValidationException(
          'Share exceeds its total size limit.',
        );
      }
    }
  }

  void _validateManifestFiles(
    VaultShareManifest manifest,
    Map<String, Uint8List> files,
  ) {
    if (manifest.entries.length != files.length) {
      throw const VaultShareValidationException(
        'Manifest does not describe every share entry.',
      );
    }
    for (final entry in manifest.entries) {
      final bytes = files[entry.path];
      if (bytes == null ||
          bytes.length != entry.size ||
          vaultShareSha256(bytes) != entry.sha256) {
        throw VaultShareValidationException(
          'Share entry failed integrity validation: ${entry.path}.',
        );
      }
    }
    final expected = {
      vaultShareClustersPath,
      vaultShareGraphPath,
      for (final id in manifest.mediaAttachmentIds) _mediaPath(id),
    };
    if (files.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(files.keys.toSet()).isNotEmpty) {
      throw const VaultShareValidationException(
        'Share contains an unexpected data path.',
      );
    }
  }

  List<SemanticCluster> _parseClusters(Uint8List bytes) {
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! List) {
      throw const VaultShareValidationException('Invalid cluster data.');
    }
    final ids = <String>{};
    final result = raw
        .map((item) {
          if (item is! Map) {
            throw const VaultShareValidationException('Invalid cluster row.');
          }
          final cluster = SemanticCluster.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (!ids.add(cluster.id)) {
            throw const VaultShareValidationException('Duplicate cluster ID.');
          }
          return cluster;
        })
        .toList(growable: false);
    return List.unmodifiable(result);
  }

  PersonalKnowledgeGraph _parseGraph(Uint8List bytes) {
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map) {
      throw const VaultShareValidationException('Invalid graph data.');
    }
    final json = Map<String, dynamic>.from(raw);
    if (json.keys.toSet().difference({
          'schemaVersion',
          'nodes',
          'edges',
        }).isNotEmpty ||
        json['schemaVersion'] != 1 ||
        json['nodes'] is! List ||
        json['edges'] is! List) {
      throw const VaultShareValidationException('Unsupported share graph.');
    }
    final nodes = (json['nodes'] as List).map((item) {
      if (item is! Map) throw const FormatException('Invalid graph node.');
      return GraphNode.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    final edges = (json['edges'] as List).map((item) {
      if (item is! Map) throw const FormatException('Invalid graph edge.');
      return GraphEdge.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    return PersonalKnowledgeGraph(schemaVersion: 2, nodes: nodes, edges: edges);
  }

  void _validateGraph(
    List<SemanticCluster> clusters,
    PersonalKnowledgeGraph graph,
  ) {
    if (graph.nodes.length > limits.maxNodes ||
        graph.edges.length > limits.maxEdges) {
      throw const VaultShareValidationException(
        'Shared graph exceeds its limits.',
      );
    }
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    if (nodeIds.length != graph.nodes.length ||
        clusters
            .expand((cluster) => cluster.nodeIds)
            .any((id) => !nodeIds.contains(id))) {
      throw const VaultShareValidationException(
        'Shared clusters reference invalid graph nodes.',
      );
    }
    final edgeIds = <String>{};
    for (final edge in graph.edges) {
      if (!edgeIds.add(edge.id) ||
          !nodeIds.contains(edge.sourceNodeId) ||
          !nodeIds.contains(edge.targetNodeId)) {
        throw const VaultShareValidationException('Invalid shared graph edge.');
      }
    }
    var citationBytes = 0;
    for (final excerpt in [
      ...graph.nodes.expand(
        (node) => node.evidence.map((item) => item.excerpt),
      ),
      ...graph.edges.expand(
        (edge) => edge.evidence.map((item) => item.excerpt),
      ),
    ]) {
      citationBytes += utf8.encode(excerpt).length;
      if (citationBytes > limits.maxCitationBytes) {
        throw const VaultShareValidationException(
          'Citation excerpts exceed their size limit.',
        );
      }
    }
  }
}

Map<String, dynamic> _exportNode(
  GraphNode node, {
  required bool includeCitations,
  required Set<String> includedMediaIds,
}) {
  final json = Map<String, dynamic>.from(node.toJson());
  json['evidence'] = includeCitations
      ? node.evidence.map((item) => item.toJson()).toList()
      : <Object>[];
  json['mediaAttachments'] = node.mediaAttachments
      .where((attachment) => includedMediaIds.contains(attachment.id))
      .map((attachment) {
        final value = attachment.toPortableJson();
        value['localPath'] = _mediaPath(attachment.id);
        return value;
      })
      .toList();
  return json;
}

Map<String, dynamic> _exportEdge(
  GraphEdge edge, {
  required bool includeCitations,
}) {
  final json = Map<String, dynamic>.from(edge.toJson());
  json['evidence'] = includeCitations
      ? edge.evidence.map((item) => item.toJson()).toList()
      : <Object>[];
  return json;
}

Uint8List _jsonBytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

String _mediaPath(String attachmentId) =>
    '$vaultShareMediaPrefix${vaultShareSha256(utf8.encode(attachmentId))}.bin';

Future<void> _rejectLink(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const VaultShareValidationException(
      'Vault share output cannot be a symlink.',
    );
  }
}

Future<void> _deleteTemporary(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on Object {
    // Preserve the original error.
  }
}

void _wipe(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}

void _wipeAll(Iterable<List<int>> values) {
  for (final value in values) {
    _wipe(value);
  }
}
