import 'dart:async';

import '../../../services/app_services.dart';
import '../presentation/offline_vault_recovery_launch_controller.dart';
import 'live_voice_lifecycle_ports.dart';
import 'offline_vault_recovery_service.dart';

/// App-root lifecycle actions for live voice capture, vault flush, and recovery.
class LiveVoiceLifecyclePolicy {
  LiveVoiceLifecyclePolicy({
    LiveVoiceCaptureLifecycle Function()? captureProvider,
    LiveVoiceRecoveryLifecycle Function()? recoveryGatewayProvider,
    OfflineVaultRecoveryService Function()? recoveryServiceProvider,
    Future<void> Function()? processPendingVaultSync,
    Future<bool> Function()? hasPendingEmergencyChunks,
    Future<void> Function()? onAppResumedForRecovery,
  }) : _captureProvider =
           captureProvider ?? (() => AppServices.instance.liveVoiceCapture),
       _recoveryGatewayProvider =
           recoveryGatewayProvider ??
           (() => AppServices.instance.liveVoiceRecoveryGateway!),
       _recoveryServiceProvider =
           recoveryServiceProvider ??
           (() => AppServices.instance.offlineVaultRecovery!),
       _processPendingVaultSync =
           processPendingVaultSync ??
           (() => AppServices.instance.vaultSyncManager!
               .processPendingVaultQueue()),
       _hasPendingEmergencyChunks =
           hasPendingEmergencyChunks ??
           (() async {
             if (!AppServices.isInitialized) return false;
             return AppServices.instance.emergencyVaultStorage!
                 .hasUncommittedChunks();
           }),
       _onAppResumedForRecovery =
           onAppResumedForRecovery ??
           OfflineVaultRecoveryLaunchController.onAppResumed;

  final LiveVoiceCaptureLifecycle Function() _captureProvider;
  final LiveVoiceRecoveryLifecycle Function() _recoveryGatewayProvider;
  final OfflineVaultRecoveryService Function() _recoveryServiceProvider;
  final Future<void> Function() _processPendingVaultSync;
  final Future<bool> Function() _hasPendingEmergencyChunks;
  final Future<void> Function() _onAppResumedForRecovery;

  Future<bool> hasUncommittedVaultData() async {
    final pending = await _recoveryServiceProvider().scanPendingVaults();
    if (pending.isNotEmpty) {
      return true;
    }
    if (await _hasPendingEmergencyChunks()) {
      return true;
    }

    final capture = _captureProvider();
    return capture.isOfflineVaultActive || capture.isActive;
  }

  void onAppBackgrounded() {
    final capture = _captureProvider();
    if (!capture.isActive) {
      return;
    }
    unawaited(_flushActiveCaptureOnBackground(capture));
  }

  Future<void> _flushActiveCaptureOnBackground(
    LiveVoiceCaptureLifecycle capture,
  ) async {
    if (!capture.isOfflineVaultActive) {
      await capture.triggerEmergencyNetworkFallback(reason: 'app_backgrounded');
    }
    await capture.pauseLiveCapture();
  }

  void onAppResumed() {
    final gateway = _recoveryGatewayProvider();
    gateway.notifyConnectivityRestored();
    unawaited(gateway.checkForPendingRecovery());
    unawaited(_processPendingVaultSync());
    unawaited(_onAppResumedForRecovery());
    unawaited(_captureProvider().resumeLiveCaptureIfActive());
  }

  void onAppTerminated() {
    unawaited(_captureProvider().terminateActiveSession());
  }
}
