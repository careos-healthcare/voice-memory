import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
  });

  test('caregiver mode is off by default', () {
    CaregiverFeatureFlags.debugOverride = null;
    expect(CaregiverFeatureFlags.isCaregiverModeEnabled, isFalse);
  });

  test('debug override can enable caregiver mode for tests', () {
    CaregiverFeatureFlags.debugOverride = true;
    expect(CaregiverFeatureFlags.isCaregiverModeEnabled, isTrue);
  });
}