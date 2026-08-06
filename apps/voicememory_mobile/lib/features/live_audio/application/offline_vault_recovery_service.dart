import 'dart:io';

import '../../../services/capture_attest_service.dart';
import '../../../services/capture_pipeline_service.dart';
import '../../../api/api_client.dart';
import '../domain/models/offline_vault_manifest.dart';
import '../infrastructure/local_audio_vault_reader.dart';
import '../infrastructure/live_audio_pipeline_log.dart';
import '../infrastructure/offline_vault_recovery_store.dart';

/// Orchestrates pending offline vault queue jobs: scan → upload → server ack → delete.
class OfflineVaultRecoveryService {
  OfflineVaultRecoveryService({
    required this._store,
    required this._api,
    required this._attest,
    required this._pipeline,
  });

  final OfflineVaultRecoveryStore _store;
  final ApiClient _api;
  final CaptureAttestService _attest;
  final CapturePipelineService _pipeline;

  /// Scans disk for orphan vault files and returns pending queue jobs.
  Future<List<OfflineVaultManifest>> scanPendingVaults() async {
    await _store.discoverOrphans();
    return _store.listPending();
  }

  Future<OfflineVaultManifest?> newestPendingVault() async {
    await _store.discoverOrphans();
    return _store.newestPending();
  }

  Future<CapturePipelineResult> recoverVault(
    OfflineVaultManifest manifest, {
    void Function(PipelineStage stage)? onStage,
  }) async {
    if (!manifest.serverRecoverable) {
      throw StateError(
        'Vault session ${manifest.sessionId} cannot be recovered via server upload.',
      );
    }

    if (manifest.requiresInlineRecoverySecret &&
        manifest.recoverySecretKeyBytes == null) {
      throw StateError(
        'Offline vault ${manifest.sessionId} is missing recovery_secret.',
      );
    }

    final vaultFile = File(manifest.vaultPath);
    if (!await vaultFile.exists()) {
      await _store.discard(manifest);
      throw StateError('Vault file is missing.');
    }

    LiveAudioPipelineLog.offlineVaultRecoveryStarted(
      sessionId: manifest.sessionId,
    );
    await _store.markUploading(manifest);

    try {
      final token = await _attest.ensureCaptureToken();
      final serverResult = await _api.postVaultRecovery(
        vaultFile: vaultFile,
        sessionId: manifest.sessionId,
        durationSeconds: manifest.durationSeconds,
        captureToken: token,
        idempotencyKey: manifest.idempotencyKey,
        recoverySecretKeyBytes: manifest.recoverySecretKeyBytes,
      );

      final pipelineResult = await _pipeline.saveRecoveredVaultEntry(
        transcript: serverResult.transcript,
        reflectionJson: serverResult.reflectionJson,
        durationSeconds: serverResult.durationSeconds,
        onStage: onStage,
      );

      await _store.markCompleted(
        manifest,
        recoveryAckId: serverResult.recoveryAckId,
      );

      LiveAudioPipelineLog.offlineVaultRecoveryAck(
        sessionId: manifest.sessionId,
        recoveryAckId: serverResult.recoveryAckId,
        duplicate: serverResult.duplicate,
      );
      return pipelineResult;
    } catch (error) {
      LiveAudioPipelineLog.offlineVaultRecoveryFailed(
        sessionId: manifest.sessionId,
        reason: error is Exception ? error.toString() : '$error',
      );
      await _store.markFailed(
        manifest,
        error: error is Exception ? error.toString() : '$error',
      );
      rethrow;
    }
  }

  Future<void> discardVault(OfflineVaultManifest manifest) {
    return _store.discard(manifest);
  }

  static int estimateDurationForManifest({
    required int frameCount,
    required int fallbackSeconds,
  }) {
    if (frameCount > 0) {
      return LocalAudioVaultReader.estimateDurationSeconds(
        frameCount: frameCount,
      );
    }
    return fallbackSeconds.clamp(1, 999999);
  }
}
