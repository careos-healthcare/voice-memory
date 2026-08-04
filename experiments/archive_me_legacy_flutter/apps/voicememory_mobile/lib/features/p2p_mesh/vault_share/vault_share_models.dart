import 'dart:collection';
import 'dart:typed_data';

import '../../../core/graph/personal_knowledge_graph.dart';
import '../../semantic_clusters/semantic_cluster.dart';

final class VaultShareLimits {
  const VaultShareLimits({
    this.maxClusters = 100,
    this.maxNodes = 2000,
    this.maxEdges = 5000,
    this.maxMedia = 100,
    this.maxCitationBytes = 2 * 1024 * 1024,
    this.maxEntryBytes = 64 * 1024 * 1024,
    this.maxTotalBytes = 256 * 1024 * 1024,
    this.maxEnvelopeBytes = 257 * 1024 * 1024,
  });

  final int maxClusters;
  final int maxNodes;
  final int maxEdges;
  final int maxMedia;
  final int maxCitationBytes;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxEnvelopeBytes;
}

final class VaultSharePassword {
  VaultSharePassword(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    if (value.length < 12 || value.length > 1024) {
      throw const VaultShareValidationException(
        'Share passwords must contain between 12 and 1024 characters.',
      );
    }
    return value;
  }
}

final class VaultShareSelection {
  VaultShareSelection({
    required Iterable<String> clusterIds,
    this.includeCitationExcerpts = false,
    Iterable<String> mediaAttachmentIds = const [],
  }) : clusterIds = UnmodifiableSetView(_ids(clusterIds, 'clusterIds')),
       mediaAttachmentIds = UnmodifiableSetView(
         _ids(mediaAttachmentIds, 'mediaAttachmentIds'),
       ) {
    if (this.clusterIds.isEmpty) {
      throw const VaultShareValidationException(
        'At least one semantic cluster must be selected.',
      );
    }
  }

  final Set<String> clusterIds;
  final bool includeCitationExcerpts;
  final Set<String> mediaAttachmentIds;

  static Set<String> _ids(Iterable<String> values, String field) {
    final result = <String>{};
    for (final value in values) {
      final id = value.trim();
      if (id.isEmpty || id.length > 256) {
        throw VaultShareValidationException('Invalid $field value.');
      }
      result.add(id);
    }
    return result;
  }
}

abstract interface class VaultShareBiometricAuthorizer {
  /// Must return false when biometric authorization is unavailable or denied.
  Future<bool> authorizeVaultShare(VaultShareSelection selection);
}

abstract interface class VaultShareSigner {
  String get signerId;
  Uint8List get publicKeyBytes;
  Future<Uint8List> sign(Uint8List message);
}

abstract interface class VaultShareSignatureVerifier {
  Future<bool> verify({
    required Uint8List message,
    required Uint8List signature,
    required Uint8List publicKeyBytes,
  });
}

abstract interface class VaultShareSignerTrust {
  /// Trust requires both the stable signer ID and exact public key to match.
  bool isTrusted({required String signerId, required Uint8List publicKeyBytes});
}

abstract interface class VaultShareMediaProvider {
  /// Returns authorized portable bytes. The `.vshare` envelope immediately
  /// encrypts them, and the recipient branch store encrypts them again at rest.
  Future<Uint8List> readPortableMedia(String attachmentId);
}

enum VaultShareSignerStatus { trusted, unknown }

final class VaultShareSignerAttribution {
  const VaultShareSignerAttribution({
    required this.signerId,
    required this.publicKeyFingerprint,
    required this.status,
  });

  final String signerId;
  final String publicKeyFingerprint;
  final VaultShareSignerStatus status;

  bool get isTrusted => status == VaultShareSignerStatus.trusted;
}

final class SharedVaultBranch {
  SharedVaultBranch({
    required this.shareId,
    required DateTime createdAt,
    required DateTime importedAt,
    required this.attribution,
    required Iterable<SemanticCluster> clusters,
    required this.graph,
    Map<String, Uint8List> encryptedMedia = const {},
  }) : createdAt = createdAt.toUtc(),
       importedAt = importedAt.toUtc(),
       clusters = UnmodifiableListView(List.of(clusters)),
       encryptedMedia = UnmodifiableMapView({
         for (final entry in encryptedMedia.entries)
           entry.key: Uint8List.fromList(entry.value),
       });

  final String shareId;
  final DateTime createdAt;
  final DateTime importedAt;
  final VaultShareSignerAttribution attribution;
  final List<SemanticCluster> clusters;
  final PersonalKnowledgeGraph graph;
  final Map<String, Uint8List> encryptedMedia;
}

sealed class VaultShareException implements Exception {
  const VaultShareException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class VaultShareValidationException extends VaultShareException {
  const VaultShareValidationException(super.message);
}

final class VaultShareAuthenticationException extends VaultShareException {
  const VaultShareAuthenticationException()
    : super('The password is wrong or the share was tampered with.');
}

final class VaultShareAuthorizationException extends VaultShareException {
  const VaultShareAuthorizationException()
    : super('Biometric authorization is required to export a vault share.');
}

final class VaultShareSignatureException extends VaultShareException {
  const VaultShareSignatureException()
    : super('The vault share signature is invalid.');
}
