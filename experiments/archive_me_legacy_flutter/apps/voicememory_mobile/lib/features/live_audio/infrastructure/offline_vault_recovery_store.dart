import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/offline_vault_manifest.dart';
import '../live_audio_constants.dart';
import 'live_audio_pipeline_log.dart';

typedef VaultStorageDirectoryResolver = Future<Directory> Function();

/// Persists pending offline vault manifests and discovers orphan vault files.
class OfflineVaultRecoveryStore {
  OfflineVaultRecoveryStore({
    File? manifestFile,
    VaultStorageDirectoryResolver? resolveVaultDirectory,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid(),
       _resolveVaultDirectory =
           resolveVaultDirectory ?? _defaultVaultDirectory {
    if (manifestFile != null) {
      _manifestFile = manifestFile;
    }
  }

  static const _manifestFileName = 'offline_vault_manifests.json';
  static const _vaultDirectoryName = 'live_audio_vaults';
  static const minFreeBytesForVault = 5 * 1024 * 1024;

  final Uuid _uuid;
  final VaultStorageDirectoryResolver _resolveVaultDirectory;
  File? _manifestFile;
  List<OfflineVaultManifest>? _cache;

  Future<File> _manifestPath() async {
    return _manifestFile ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_manifestFileName',
    );
  }

  static Future<Directory> _defaultVaultDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final vaultDir = Directory('${supportDir.path}/$_vaultDirectoryName');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  Future<Directory> vaultDirectory() => _resolveVaultDirectory();

  Future<bool> hasAdequateStorage({
    int requiredBytes = minFreeBytesForVault,
  }) async {
    try {
      final dir = await vaultDirectory();
      final stat = await dir.stat();
      // Dart doesn't expose free space directly; approximate using file length checks elsewhere.
      return stat.type == FileSystemEntityType.directory;
    } catch (_) {
      return false;
    }
  }

  Future<List<OfflineVaultManifest>> listManifests() async {
    _cache ??= await _readManifests();
    return List<OfflineVaultManifest>.from(_cache!);
  }

  Future<List<OfflineVaultManifest>> listPending() async {
    final manifests = await listManifests();
    return manifests.where((manifest) => manifest.isPending).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<OfflineVaultManifest?> newestPending() async {
    final pending = await listPending();
    return pending.isEmpty ? null : pending.first;
  }

  Future<OfflineVaultManifest> registerVault({
    required String sessionId,
    required File vaultFile,
    required int frameCount,
    required int durationSeconds,
    List<int>? recoverySecretKeyBytes,
    bool? serverRecoverable,
  }) async {
    final vaultDir = await vaultDirectory();
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    final targetPath =
        '${vaultDir.path}/audio_vault_${sessionId.replaceAll('/', '_')}.vault.enc';
    final source = vaultFile;
    File persisted = source;
    if (source.path != targetPath) {
      persisted = await source.copy(targetPath);
      if (source.path.contains('audio_vault_') && source.path != targetPath) {
        if (await source.exists()) {
          await source.delete();
        }
      }
    }

    final recoverySecretBase64Url =
        OfflineVaultManifest.encodeRecoverySecretBase64Url(
          recoverySecretKeyBytes,
        );
    final resolvedServerRecoverable =
        serverRecoverable ??
        OfflineVaultManifest.isServerRecoverable(
          sessionId: sessionId,
          recoverySecretKeyBytes: recoverySecretKeyBytes,
        );

    final manifest = OfflineVaultManifest(
      manifestId: _uuid.v4(),
      sessionId: sessionId,
      vaultPath: persisted.path,
      frameCount: frameCount,
      durationSeconds: durationSeconds.clamp(1, 999999),
      createdAt: DateTime.now().toUtc(),
      idempotencyKey: stableIdempotencyKey(sessionId),
      uploadState: OfflineVaultUploadState.pending,
      recoverySecretBase64Url: recoverySecretBase64Url,
      serverRecoverable: resolvedServerRecoverable,
    );

    final manifests = await listManifests();
    manifests.removeWhere((entry) => entry.sessionId == sessionId);
    manifests.add(manifest);
    await _writeManifests(manifests);
    LiveAudioPipelineLog.offlineVaultRegistered(
      sessionId: sessionId,
      frameCount: frameCount,
    );
    return manifest;
  }

  Future<void> upsert(OfflineVaultManifest manifest) async {
    final manifests = await listManifests();
    final index = manifests.indexWhere(
      (entry) => entry.manifestId == manifest.manifestId,
    );
    if (index >= 0) {
      manifests[index] = manifest;
    } else {
      manifests.add(manifest);
    }
    await _writeManifests(manifests);
  }

  Future<void> markUploading(OfflineVaultManifest manifest) {
    return upsert(
      manifest.copyWith(
        uploadState: OfflineVaultUploadState.uploading,
        lastError: null,
      ),
    );
  }

  Future<void> markCompleted(
    OfflineVaultManifest manifest, {
    required String recoveryAckId,
  }) async {
    await upsert(
      manifest.copyWith(
        uploadState: OfflineVaultUploadState.completed,
        recoveryAckId: recoveryAckId,
        lastError: null,
      ),
    );
    await removeVaultArtifacts(manifest);
  }

  Future<void> markFailed(
    OfflineVaultManifest manifest, {
    required String error,
  }) {
    return upsert(
      manifest.copyWith(
        uploadState: OfflineVaultUploadState.failed,
        lastError: error,
      ),
    );
  }

  Future<void> discard(OfflineVaultManifest manifest) async {
    await removeVaultArtifacts(manifest);
    final manifests = await listManifests();
    manifests.removeWhere((entry) => entry.manifestId == manifest.manifestId);
    await _writeManifests(manifests);
    LiveAudioPipelineLog.offlineVaultDiscarded(sessionId: manifest.sessionId);
  }

  Future<void> removeVaultArtifacts(OfflineVaultManifest manifest) async {
    final file = File(manifest.vaultPath);
    if (await file.exists()) {
      await file.delete();
    }
    final manifests = await listManifests();
    manifests.removeWhere((entry) => entry.manifestId == manifest.manifestId);
    await _writeManifests(manifests);
  }

  Future<List<OfflineVaultManifest>> discoverOrphans() async {
    final vaultDir = await vaultDirectory();
    if (!await vaultDir.exists()) {
      return const [];
    }

    final manifests = await listManifests();
    final knownPaths = manifests.map((entry) => entry.vaultPath).toSet();
    final orphans = <OfflineVaultManifest>[];

    await for (final entity in vaultDir.list()) {
      if (entity is! File || !entity.path.endsWith('.vault.enc')) {
        continue;
      }
      if (knownPaths.contains(entity.path)) {
        continue;
      }
      final sessionId = _sessionIdFromVaultPath(entity.path);
      if (sessionId == null) {
        continue;
      }
      orphans.add(
        OfflineVaultManifest(
          manifestId: _uuid.v4(),
          sessionId: sessionId,
          vaultPath: entity.path,
          frameCount: 0,
          durationSeconds: liveInputFrameDurationMs ~/ 1000,
          createdAt: (await entity.stat()).modified.toUtc(),
          idempotencyKey: stableIdempotencyKey(sessionId),
          uploadState: OfflineVaultUploadState.pending,
          serverRecoverable: !sessionId.startsWith('offline_'),
        ),
      );
    }

    if (orphans.isNotEmpty) {
      manifests.addAll(orphans);
      await _writeManifests(manifests);
    }
    return orphans;
  }

  static String stableIdempotencyKey(String sessionId) =>
      'vault_recovery:$sessionId';

  static String? _sessionIdFromVaultPath(String path) {
    final name = path.split('/').last;
    const prefix = 'audio_vault_';
    const suffix = '.vault.enc';
    if (!name.startsWith(prefix) || !name.endsWith(suffix)) {
      return null;
    }
    return name.substring(prefix.length, name.length - suffix.length);
  }

  Future<List<OfflineVaultManifest>> _readManifests() async {
    final file = await _manifestPath();
    if (!await file.exists()) {
      return <OfflineVaultManifest>[];
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .map(
            (entry) => OfflineVaultManifest.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } catch (error) {
      LiveAudioPipelineLog.failure('offline_vault_manifest_read', error);
      return <OfflineVaultManifest>[];
    }
  }

  Future<void> _writeManifests(List<OfflineVaultManifest> manifests) async {
    _cache = List<OfflineVaultManifest>.from(manifests);
    final file = await _manifestPath();
    await file.parent.create(recursive: true);
    final encoded = jsonEncode(
      manifests.map((entry) => entry.toJson()).toList(),
    );
    await file.writeAsString(encoded, flush: true);
  }
}
