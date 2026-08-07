import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/di/v1_dependency_scopes.dart';

void main() {
  test('device-global services are isolated from account scope', () {
    for (final name in V1DependencyScopeRegistry.deviceGlobalServices) {
      expect(
        V1DependencyScopeRegistry.scopeFor(name),
        V1DependencyScope.deviceGlobal,
      );
    }
  });

  test('account-scoped services cover persistence and billing', () {
    expect(
      V1DependencyScopeRegistry.scopeFor('JournalStore'),
      V1DependencyScope.accountScoped,
    );
    expect(
      V1DependencyScopeRegistry.scopeFor('ArchiveCorrectionStore'),
      V1DependencyScope.accountScoped,
    );
    expect(
      V1DependencyScopeRegistry.scopeFor('RemoteProcessingConsentStore'),
      V1DependencyScope.accountScoped,
    );
    expect(
      V1DependencyScopeRegistry.scopeFor('EncryptedSyncService'),
      V1DependencyScope.accountScoped,
    );
    expect(
      V1DependencyScopeRegistry.scopeFor('BillingService'),
      V1DependencyScope.accountScoped,
    );
  });

  test('flow-scoped controllers stay off the service locator', () {
    for (final name in V1DependencyScopeRegistry.flowScopedServices) {
      expect(
        V1DependencyScopeRegistry.scopeFor(name),
        V1DependencyScope.flowScoped,
      );
    }
  });

  test('service locator exception documents blocked path', () {
    final error = V1ServiceLocatorAccessException('capture/save');
    expect(error.toString(), contains('capture/save'));
    expect(error.toString(), contains('AppServices.instance'));
  });
}
