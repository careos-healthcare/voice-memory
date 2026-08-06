/// Explicit dependency scopes for V1 — replaces implicit [AppServices.instance]
/// access on critical paths incrementally.
enum V1DependencyScope {
  /// Process-wide services: connectivity, device id, secure storage factory.
  deviceGlobal,

  /// Per-account namespace: journal, prefs, sync, billing entitlements.
  accountScoped,

  /// Single screen or flow: capture pipeline run, paywall purchase attempt.
  flowScoped,
}

/// Documents which subsystems belong to each scope. Validators ensure new V1
/// modules declare their scope before accessing persistent storage.
abstract final class V1DependencyScopeRegistry {
  V1DependencyScopeRegistry._();

  static const deviceGlobalServices = {
    'DeviceIdStore',
    'SecureStorageService',
    'NetworkConnectivitySource',
    'LocalAudioVault',
  };

  static const accountScopedServices = {
    'JournalStore',
    'MobilePrefsStore',
    'EncryptedSyncService',
    'AuthService',
    'BillingService',
    'CapturePipelineService',
  };

  static const flowScopedServices = {
    'RecordScreenViewModel',
    'PaywallController',
    'RecordingRecoveryController',
  };

  static V1DependencyScope scopeFor(String serviceName) {
    if (deviceGlobalServices.contains(serviceName)) {
      return V1DependencyScope.deviceGlobal;
    }
    if (accountScopedServices.contains(serviceName)) {
      return V1DependencyScope.accountScoped;
    }
    if (flowScopedServices.contains(serviceName)) {
      return V1DependencyScope.flowScoped;
    }
    return V1DependencyScope.accountScoped;
  }
}

/// Thrown when V1 code accesses [AppServices.instance] on a flow-scoped path
/// that should receive explicit dependencies instead.
class V1ServiceLocatorAccessException implements Exception {
  V1ServiceLocatorAccessException(this.path);

  final String path;

  @override
  String toString() =>
      'V1ServiceLocatorAccessException: avoid AppServices.instance in $path';
}
