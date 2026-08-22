import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/watch_companion_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    WatchCompanionFeatureFlags.debugOverride = null;
  });

  test('watch companion is off by default', () {
    WatchCompanionFeatureFlags.debugOverride = null;
    expect(WatchCompanionFeatureFlags.enableWatchCompanion, isFalse);
    expect(V1CapabilityRegistry.watchCompanion, isFalse);
  });

  test('debug override enables watch companion capability', () {
    WatchCompanionFeatureFlags.debugOverride = true;
    expect(V1CapabilityRegistry.watchCompanion, isTrue);
  });
}