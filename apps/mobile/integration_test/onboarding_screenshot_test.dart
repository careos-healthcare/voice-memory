import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/ui_screenshot_audit.dart';

/// Captures onboarding-1.png … onboarding-5.png under the audit output root.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('belief-first onboarding screenshot audit', (
    WidgetTester tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    final runner = UiScreenshotAuditRunner(binding: binding, tester: tester);

    final report = await runner.runOnboardingScreenshotAudit();

    final onboardingCaptures = report.captures
        .where((c) => c.filename.startsWith('onboarding-'))
        .toList();
    expect(onboardingCaptures.length, 5);
    for (var i = 1; i <= 5; i++) {
      expect(
        onboardingCaptures.any((c) => c.filename == 'onboarding-$i.png'),
        isTrue,
        reason: 'Missing onboarding-$i.png',
      );
    }
  });
}