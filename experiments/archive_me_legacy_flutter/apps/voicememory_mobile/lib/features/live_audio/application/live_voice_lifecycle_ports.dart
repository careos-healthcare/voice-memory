/// Narrow capture surface used by app lifecycle transitions.
abstract class LiveVoiceCaptureLifecycle {
  bool get isActive;
  bool get isOfflineVaultActive;
  Future<void> triggerEmergencyNetworkFallback({String? reason});
  Future<void> pauseLiveCapture();
  Future<void> resumeLiveCaptureIfActive();
  Future<void> terminateActiveSession();
}

/// Narrow recovery sweep surface used on app resume.
abstract class LiveVoiceRecoveryLifecycle {
  void notifyConnectivityRestored();
  Future<void> checkForPendingRecovery();
}
