import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup coordinator source defers optional services', () {
    final startup = File(
      'lib/startup/v1_startup_coordinator.dart',
    ).readAsStringSync();
    final bootstrap = File(
      'lib/startup/archive_me_startup.dart',
    ).readAsStringSync();
    final appServices = File(
      'lib/services/app_services.dart',
    ).readAsStringSync();

    expect(startup, contains('runEssentialPhases'));
    expect(startup, contains('runOptionalPhases'));
    expect(startup, contains('initializeEssential'));
    expect(startup, contains('initializeOptionalServices'));
    expect(bootstrap, isNot(contains('AppServices.initialize();')));
    expect(
      bootstrap,
      contains('unawaited(V1StartupCoordinator.runOptionalPhases())'),
    );
    expect(appServices, contains('static Future<void> initializeEssential()'));
    expect(
      appServices,
      contains('static Future<void> initializeOptionalServices()'),
    );
  });

  test('bootstrap failure UI uses fixed copy not raw exceptions', () {
    final bootstrap = File(
      'lib/startup/archive_me_startup.dart',
    ).readAsStringSync();
    expect(bootstrap, contains('ConsumerUiCopy.startupLocalStorageFailedBody'));
    expect(bootstrap, isNot(contains(r'$_startupError')));
  });

  test('startup phases match production allowlist contract', () {
    final ids = V1ProductionAllowlist.startupPhases.map((p) => p.id).toList();
    expect(ids, [
      'privacy_safe_shell',
      'essential_local_archive',
      'v1_navigation',
      'optional_async_services',
    ]);
    expect(
      ConsumerUiCopy.startupLocalStorageFailedBody,
      isNot(contains('Exception')),
    );
  });
}