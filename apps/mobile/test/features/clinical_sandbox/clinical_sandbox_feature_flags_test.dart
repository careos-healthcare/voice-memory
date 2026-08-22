import 'package:archiveme_mobile/features/clinical_sandbox/config/clinical_sandbox_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ClinicalSandboxFeatureFlags.debugOverride = null;
  });

  group('ClinicalSandboxFeatureFlags', () {
    test('defaults to disabled without debug override', () {
      expect(ClinicalSandboxFeatureFlags.isEnabled, isFalse);
    });

    test('debug override can enable for internal QA', () {
      ClinicalSandboxFeatureFlags.debugOverride = true;
      expect(ClinicalSandboxFeatureFlags.isEnabled, isTrue);
    });

    test('assertSafeForPublicDistribution is a no-op when compile flag is off',
        () {
      expect(
        ClinicalSandboxFeatureFlags.assertSafeForPublicDistribution,
        returnsNormally,
      );
    });
  });
}