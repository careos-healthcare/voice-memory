import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';

/// Monitors network restoration and sweeps pending vault files for upload + ack.
class LiveVoiceRecoveryGateway {
  LiveVoiceRecoveryGateway({
    required this._vault,
    required this._connectivity,
    required this._recoveryStore,
    required this._recoveryService,
    required this._consentGate,
  }) {
    _initRecoveryListener();
  }

  final LocalAudioVault _vault;
  final NetworkConnectivitySource _connectivity;
  final OfflineVaultRecoveryStore _recoveryStore;
  final OfflineVaultRecoveryService _recoveryService;
  final RemoteProcessingConsentGate _consentGate;

  StreamSubscription<void>? _connectivitySub;
  var _sweepInFlight = false;

  void _initRecoveryListener() {
    if (!V1CapabilityRegistry.liveVoice) return;
    _connectivitySub = _connectivity.onConnectivityRestored.listen((_) {
      unawaited(checkForPendingRecovery());
    });
  }

  /// Called on app resume when network may have returned.
  void notifyConnectivityRestored() {
    if (!V1CapabilityRegistry.liveVoice) return;
    if (_connectivity is LifecycleNetworkConnectivitySource) {
      _connectivity.notifyConnectivityRestored();
    }
  }

  Future<void> checkForPendingRecovery() async {
    if (!V1CapabilityRegistry.liveVoice) return;
    if (_sweepInFlight) return;
    _sweepInFlight = true;
    final session = AccountSessionGuard.capture();
    try {
      final consent = await _consentGate.evaluate();
      if (!consent.permitted) {
        // Vault files stay on-device until the customer opts in again.
        return;
      }

      final pendingVaults = await _vault.discoverPendingVaults();
      if (pendingVaults.isEmpty) {
        await _recoveryStore.discoverOrphans();
      } else {
        for (final vaultFile in pendingVaults) {
          await _ensureManifestRegistered(vaultFile);
        }
      }

      final pending = await _recoveryStore.listPending();
      for (final manifest in pending) {
        session.assertActive();
        await _recoverManifest(manifest);
      }
    } finally {
      _sweepInFlight = false;
    }
  }

  Future<void> _ensureManifestRegistered(File vaultFile) async {
    final metadata = await _vault.extractVaultMetadata(vaultFile);
    final manifests = await _recoveryStore.listManifests();
    final alreadyQueued = manifests.any(
      (entry) =>
          entry.vaultPath == vaultFile.path ||
          entry.sessionId == metadata.sessionId,
    );
    if (alreadyQueued) {
      return;
    }

    await _recoveryStore.registerVault(
      sessionId: metadata.sessionId,
      vaultFile: vaultFile,
      frameCount: metadata.frameCount,
      durationSeconds: metadata.durationSeconds,
      serverRecoverable: metadata.serverRecoverable,
    );
  }

  Future<void> _recoverManifest(OfflineVaultManifest manifest) async {
    if (!manifest.serverRecoverable) {
      return;
    }

    final vaultFile = File(manifest.vaultPath);
    if (!await vaultFile.exists()) {
      await _recoveryStore.discard(manifest);
      return;
    }

    final metadata = await _vault.extractVaultMetadata(vaultFile);

    try {
      await _recoveryService.recoverVault(manifest);
      LiveAudioPipelineLog.vaultRecoveryFinalized(
        sessionId: metadata.sessionId,
      );
    } catch (error, stackTrace) {
      LiveAudioPipelineLog.vaultRecoveryFailed(
        sessionId: metadata.sessionId,
        error: '$error',
      );
      // Hold file on disk for the next lifecycle loop retry.
    }
  }

  void dispose() {
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
    _connectivity.dispose();
  }
}