import 'dart:io';

import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault_reader.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/account_session_scope.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';

/// Orchestrates pending offline vault queue jobs: scan → upload → server ack → delete.
class OfflineVaultRecoveryService {
  OfflineVaultRecoveryService({
    required this._store,
    required this._captureRepository,
    required this._attest,
    required this._pipeline,
    required this._consentGate,
  });

  final OfflineVaultRecoveryStore _store;
  final CaptureRepository _captureRepository;
  final CaptureAttestService _attest;
  final CapturePipelineService _pipeline;
  final RemoteProcessingConsentGate _consentGate;

  Stream<PipelineState> get pipelineStates => _pipeline.pipelineStates;

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
    NetworkCancelToken? cancelToken,
  }) async {
    final session = AccountSessionGuard.capture();
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

    final consent = await _consentGate.evaluate();
    if (!consent.permitted) {
      throw const RemoteProcessingConsentRequired();
    }

    LiveAudioPipelineLog.offlineVaultRecoveryStarted(
      sessionId: manifest.sessionId,
    );
    await _store.markUploading(manifest);

    try {
      final token = await _attest.ensureCaptureToken();
      final uploadResult = await _captureRepository.postVaultRecovery(
        vaultFile: vaultFile,
        sessionId: manifest.sessionId,
        durationSeconds: manifest.durationSeconds,
        captureToken: token,
        idempotencyKey: manifest.idempotencyKey,
        recoverySecretKeyBytes: manifest.recoverySecretKeyBytes,
        cancelToken: cancelToken,
      );

      final serverResult = uploadResult.when(
        success: (value) => value,
        onFailure: (failure) => throw failure.toApiException(),
      );

      session.assertActive();
      final pipelineResult = (await _pipeline.saveRecoveredVaultEntry(
        transcript: serverResult.transcript,
        reflectionJson: serverResult.reflectionJson,
        durationSeconds: serverResult.durationSeconds,
        remoteProcessingConsented: consent.consentAtProcessingTime,
      )).getOrThrow();

      session.assertActive();
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
    } catch (error, stackTrace) {
      if (error is StaleAccountSessionException) {
        rethrow;
      }
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