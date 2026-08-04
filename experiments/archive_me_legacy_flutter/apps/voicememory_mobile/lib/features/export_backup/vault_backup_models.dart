import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:path/path.dart' as p;

enum VaultCredentialKind { password, bip39 }

final class VaultCredential {
  VaultCredential.password(String value)
    : kind = VaultCredentialKind.password,
      value = _validatePassword(value);

  VaultCredential.bip39(String value)
    : kind = VaultCredentialKind.bip39,
      value = _validateMnemonic(value);

  final VaultCredentialKind kind;
  final String value;

  static String _validatePassword(String value) {
    if (value.length < 12) {
      throw const VaultBackupValidationException(
        'Backup passwords must contain at least 12 characters.',
      );
    }
    return value;
  }

  static String _validateMnemonic(String value) {
    try {
      final normalized = value.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final mnemonic = Mnemonic.fromSentence(normalized, Language.english);
      if (mnemonic.words.length != 12) {
        throw const FormatException('Expected 12 words.');
      }
      return mnemonic.sentence;
    } on Object {
      throw const VaultBackupValidationException(
        'A valid 12-word English BIP39 phrase is required.',
      );
    }
  }
}

enum VaultPortableKey {
  privateDataEncryption,
  biometricVault,
  liveAudioVault,
  graphSync,
  e2eeSync,
}

final class VaultPortableKeyring {
  VaultPortableKeyring({
    required Map<VaultPortableKey, Uint8List> keys,
    this.syncPhrase,
  }) : keys = Map.unmodifiable({
         for (final entry in keys.entries)
           entry.key: Uint8List.fromList(entry.value),
       });

  final Map<VaultPortableKey, Uint8List> keys;
  final String? syncPhrase;

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'schema': 1,
        'keys': {
          for (final entry in keys.entries)
            entry.key.name: base64Encode(entry.value),
        },
        if (syncPhrase != null) 'syncPhrase': syncPhrase,
      }),
    ),
  );

  factory VaultPortableKeyring.fromBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('Expected object.');
      final json = Map<String, Object?>.from(decoded);
      _requireExactKeys(json, {'schema', 'keys'}, {'syncPhrase'});
      if (json['schema'] != 1 || json['keys'] is! Map) {
        throw const FormatException('Unsupported keyring schema.');
      }
      final rawKeys = Map<String, Object?>.from(json['keys']! as Map);
      final keys = <VaultPortableKey, Uint8List>{};
      for (final entry in rawKeys.entries) {
        final key = VaultPortableKey.values
            .where((candidate) => candidate.name == entry.key)
            .firstOrNull;
        if (key == null || entry.value is! String || keys.containsKey(key)) {
          throw const FormatException('Invalid portable key.');
        }
        keys[key] = Uint8List.fromList(base64Decode(entry.value! as String));
      }
      final phrase = json['syncPhrase'];
      if (phrase != null && phrase is! String) {
        throw const FormatException('Invalid sync phrase.');
      }
      return VaultPortableKeyring(keys: keys, syncPhrase: phrase as String?);
    } on VaultBackupException {
      rethrow;
    } on Object catch (error) {
      throw VaultBackupValidationException('Invalid portable keyring: $error');
    }
  }

  void wipe() {
    for (final value in keys.values) {
      wipeBytes(value);
    }
  }
}

abstract interface class VaultPortableKeyProvider {
  Future<VaultPortableKeyring> exportPortableKeys({
    required bool includeSyncPhrase,
  });
}

abstract interface class VaultPortableKeyInstaller {
  Future<void> install(VaultPortableKeyring keyring);
  Future<void> rollback();
}

abstract interface class VaultTransactionalKeyInstaller
    implements VaultPortableKeyInstaller {
  Future<void> commit();
}

abstract interface class VaultFinalizableTransactionalKeyInstaller
    implements VaultTransactionalKeyInstaller {
  /// Discards rollback material after the restored stores reopen successfully.
  Future<void> finalizeCommit();
}

abstract interface class VaultServiceLifecycle {
  Future<void> quiesce();
  Future<void> resume();
}

abstract interface class VaultRestoreLifecycle
    implements VaultServiceLifecycle {
  /// Closes file-backed stores before restore swaps begin.
  Future<void> prepareRestore();

  /// Reopens the production service graph after success or rollback.
  Future<void> finishRestore({required bool succeeded});

  /// Closes any stores that were partially reopened by a failed finish.
  Future<void> closeAfterFailedReopen();
}

abstract interface class VaultRestoreNotifier {
  Future<void> resetSyncState();
  Future<void> notifyProviders();
}

enum VaultRestoreMode { replace, merge }

abstract interface class VaultFileMergePolicy {
  Future<bool> shouldReplace({
    required String relativePath,
    required String existingSha256,
    required String backupSha256,
  });
}

final class VaultBackupWinsMergePolicy implements VaultFileMergePolicy {
  const VaultBackupWinsMergePolicy();

  @override
  Future<bool> shouldReplace({
    required String relativePath,
    required String existingSha256,
    required String backupSha256,
  }) async => true;
}

final class VaultFileSource {
  VaultFileSource({
    required this.file,
    required this.relativePath,
    Directory? containmentRoot,
  }) : containmentRoot = containmentRoot ?? file.parent;

  final File file;
  final String relativePath;
  final Directory containmentRoot;
}

final class VaultDirectorySource {
  VaultDirectorySource({
    required this.directory,
    required this.relativeRoot,
    this.allowedSuffixes = const {},
    Directory? destinationRoot,
  }) : destinationRoot = destinationRoot ?? directory;

  final Directory directory;
  final String relativeRoot;
  final Set<String> allowedSuffixes;
  final Directory destinationRoot;

  bool allowsFile(String path) =>
      allowedSuffixes.isEmpty ||
      allowedSuffixes.any((suffix) => path.endsWith(suffix));
}

/// The only files visible to backup/restore. Nothing is discovered outside
/// these exact files and directory roots.
final class VaultSourceCatalog {
  VaultSourceCatalog({
    this.files = const [],
    this.directories = const [],
    required this.restoreRoot,
    Map<String, Directory> destinationRoots = const {},
  }) : destinationRoots = Map.unmodifiable(destinationRoots) {
    for (final source in files) {
      validateSafeRelativePath(source.relativePath);
    }
    for (final source in directories) {
      validateSafeRelativePath(source.relativeRoot);
    }
  }

  final List<VaultFileSource> files;
  final List<VaultDirectorySource> directories;
  final Directory restoreRoot;

  /// Logical namespace to physical restore root. The empty namespace uses
  /// [restoreRoot]; for example `support/` maps to application support.
  final Map<String, Directory> destinationRoots;

  /// Production allowlist. Entitlements, IDs, credentials, caches, plaintext
  /// temp files, and model weights are absent by construction.
  factory VaultSourceCatalog.production(
    Directory documentsRoot, {
    Directory? supportRoot,
  }) {
    final support = supportRoot ?? documentsRoot;
    File source(String name) => File(p.join(documentsRoot.path, name));
    const encryptedStores = [
      'journal_entries.enc',
      'personal_knowledge_graph.enc',
      'temporal_graph_history.enc',
      'semantic_archive_index.enc',
      'hybrid_local_semantic.enc',
      'semantic_clusters.enc',
      'life_simulator_scenarios.enc',
      'horizon_lab.sqlite3',
      'horizon_lab.sqlite3-wal',
      'horizon_lab.sqlite3-shm',
      'mesh_incoming.sqlite3',
      'mesh_incoming.sqlite3-wal',
      'mesh_incoming.sqlite3-shm',
      'whispering_vault.sqlite3',
      'whispering_vault.sqlite3-wal',
      'whispering_vault.sqlite3-shm',
      'autonomous_muse.sqlite3',
      'autonomous_muse.sqlite3-wal',
      'autonomous_muse.sqlite3-shm',
      'neural_dataset.enc',
      'neural_adapters.sqlite3',
      'neural_adapters.sqlite3-wal',
      'neural_adapters.sqlite3-shm',
      'action_plans.enc',
      'document_semantic_index.enc',
      'document_graph_overlay.enc',
      'mesh_trusted_peers.enc',
      'mesh_sync_checkpoints.enc',
      'hivemind_governance.enc',
      'spatial_nexus_preferences.enc',
      'apex_audits/apex_latest.apex-audit',
      'catalyst_workflows.enc',
      'sandbox_enclave.enc',
      'codex_publication_history.enc',
      'shared_vault_branches.enc',
      'morning_briefings.enc',
      'morning_briefing_audio.enc',
      'shared_vault/shared_vault_outbox.db',
      'shared_vault/shared_vault_outbox.db-wal',
      'shared_vault/shared_vault_outbox.db-shm',
      'capture_api_retry_queue.enc',
      'explainability_history.enc',
      'ai_cost_telemetry.enc',
      'encrypted_graph_sync_queue.enc',
      'e2ee_sync_outbox.db',
      'e2ee_sync_outbox.db-wal',
      'e2ee_sync_outbox.db-shm',
      'transcription_queue/transcription_jobs.sqlite3',
      'transcription_queue/transcription_jobs.sqlite3-wal',
      'transcription_queue/transcription_jobs.sqlite3-shm',
    ];
    return VaultSourceCatalog(
      restoreRoot: documentsRoot,
      destinationRoots: {'support': support},
      files: [
        for (final relativePath in encryptedStores)
          VaultFileSource(
            file: source(relativePath),
            relativePath: relativePath,
            containmentRoot: documentsRoot,
          ),
      ],
      directories: [
        VaultDirectorySource(
          directory: Directory(p.join(support.path, 'encrypted_audio_vault')),
          relativeRoot: 'support/encrypted_audio_vault',
          allowedSuffixes: const {'.enc'},
          destinationRoot: support,
        ),
        VaultDirectorySource(
          directory: Directory(
            p.join(documentsRoot.path, 'transcription_queue/audio'),
          ),
          relativeRoot: 'transcription_queue/audio',
          allowedSuffixes: const {'.vault'},
        ),
        VaultDirectorySource(
          directory: Directory(p.join(documentsRoot.path, 'encrypted_media')),
          relativeRoot: 'encrypted_media',
          allowedSuffixes: const {'.vault'},
        ),
        VaultDirectorySource(
          directory: Directory(p.join(documentsRoot.path, 'document_vault')),
          relativeRoot: 'document_vault',
          allowedSuffixes: const {'.vault'},
        ),
        VaultDirectorySource(
          directory: Directory(p.join(documentsRoot.path, 'neural_adapters')),
          relativeRoot: 'neural_adapters',
          allowedSuffixes: const {'.enc'},
        ),
        VaultDirectorySource(
          directory: Directory(p.join(support.path, 'live_audio_vaults')),
          relativeRoot: 'support/live_audio_vaults',
          allowedSuffixes: const {'.vault.enc'},
          destinationRoot: support,
        ),
        VaultDirectorySource(
          directory: Directory(
            p.join(support.path, 'live_audio_emergency_chunks'),
          ),
          relativeRoot: 'support/live_audio_emergency_chunks',
          allowedSuffixes: const {'.bin', '.meta.json'},
          destinationRoot: support,
        ),
      ],
    );
  }

  File destinationFor(String relativePath) {
    validateSafeRelativePath(relativePath);
    final parts = p.posix.split(relativePath);
    final namespaceRoot = destinationRoots[parts.first];
    final rootDirectory = namespaceRoot ?? restoreRoot;
    final destinationParts = namespaceRoot == null ? parts : parts.skip(1);
    if (namespaceRoot != null && parts.length == 1) {
      throw VaultBackupValidationException(
        'Restore path must name a file inside $relativePath.',
      );
    }
    final destination = File(
      p.joinAll([rootDirectory.path, ...destinationParts]),
    );
    final root = p.canonicalize(rootDirectory.absolute.path);
    final candidate = p.canonicalize(destination.absolute.path);
    if (candidate != root && !p.isWithin(root, candidate)) {
      throw VaultBackupValidationException(
        'Restore path escapes its root: $relativePath.',
      );
    }
    return destination;
  }

  Directory destinationRootFor(String relativePath) {
    validateSafeRelativePath(relativePath);
    return destinationRoots[p.posix.split(relativePath).first] ?? restoreRoot;
  }

  bool allows(String relativePath) {
    if (files.any((source) => source.relativePath == relativePath)) return true;
    return directories.any(
      (source) =>
          relativePath != source.relativeRoot &&
          p.posix.isWithin(source.relativeRoot, relativePath) &&
          source.allowsFile(relativePath),
    );
  }
}

final class VaultBackupLimits {
  const VaultBackupLimits({
    this.maxEntries = 10000,
    this.maxEntryBytes = 256 * 1024 * 1024,
    this.maxTotalBytes = 2 * 1024 * 1024 * 1024,
    this.maxEnvelopeBytes = 2 * 1024 * 1024 * 1024 + 1024 * 1024,
  });

  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxEnvelopeBytes;
}

sealed class VaultBackupException implements Exception {
  const VaultBackupException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class VaultBackupValidationException extends VaultBackupException {
  const VaultBackupValidationException(super.message);
}

final class VaultBackupAuthenticationException extends VaultBackupException {
  const VaultBackupAuthenticationException()
    : super('The credential is wrong or the backup was tampered with.');
}

final class VaultRestoreException extends VaultBackupException {
  const VaultRestoreException(super.message);
}

void validateSafeRelativePath(String value) {
  final normalized = p.posix.normalize(value);
  if (value.isEmpty ||
      value.contains('\u0000') ||
      value.contains('\\') ||
      value.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(value) ||
      normalized == '.' ||
      normalized == '..' ||
      normalized.startsWith('../') ||
      normalized != value) {
    throw VaultBackupValidationException('Unsafe relative path: $value.');
  }
}

void wipeBytes(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}

void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> required,
  Set<String> optional,
) {
  if (!json.keys.toSet().containsAll(required) ||
      json.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    throw const FormatException('Unexpected or missing fields.');
  }
}
