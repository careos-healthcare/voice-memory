import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production router imports only focused V1 surfaces', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final forbidden in [
      'life_os',
      'memory_graph',
      'document_ingestion',
      'mesh_exchange',
      'p2p_mesh',
      'life_simulator',
      'healthkit',
      'vision',
      'scanner',
      'live_voice_session',
      'future_preview',
      'archive_analyst',
      'blind_spot',
    ]) {
      expect(router, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(router, isNot(contains("'../screens/settings_screen.dart'")));
    expect(router, isNot(contains("'../screens/account_screen.dart'")));
    expect(
      RegExp(r'StatefulShellBranch\s*\(').allMatches(router),
      hasLength(4),
    );
  });

  test('stale feature paths are represented by safe V1 fallbacks', () {
    final contract = File(
      'lib/product/archive_me_v1_product_contract.dart',
    ).readAsStringSync();
    for (final path in [
      '/life-os',
      '/life-os/graph',
      '/archive-tools',
      '/self-discovery',
      '/live-voice',
      '/weekly-report',
    ]) {
      expect(contract, contains("'$path'"), reason: path);
    }
  });

  test('native production entry points expose only V1 channels', () {
    final android = File(
      'android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    for (final forbidden in [
      'calendar',
      'health',
      'graph_sync',
      'neural_hardware',
      'current_objective_widget',
      'android_os_integration',
      'model_storage',
    ]) {
      expect(
        android.toLowerCase(),
        isNot(contains(forbidden)),
        reason: forbidden,
      );
      expect(ios.toLowerCase(), isNot(contains(forbidden)), reason: forbidden);
    }
    for (final required in [
      'native_audio_recorder',
      'sensitive_temporary_audio_store',
    ]) {
      expect(android, contains(required), reason: required);
      expect(ios, contains(required), reason: required);
    }
  });
}
