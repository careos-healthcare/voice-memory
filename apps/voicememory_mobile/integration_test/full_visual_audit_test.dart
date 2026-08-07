import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/full_visual_audit_runner.dart';

const _expectedScreenshotCount = int.fromEnvironment(
  'EXPECTED_SCREENSHOT_COUNT',
  defaultValue: 75,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full visual audit crawl', (WidgetTester tester) async {
    final runner = FullVisualAuditRunner(binding: binding, tester: tester);

    final report = await runner.runFullAudit();
    expect(
      report.totalScreenshots,
      greaterThanOrEqualTo(_expectedScreenshotCount),
      reason:
          'Visual audit should capture at least $_expectedScreenshotCount '
          'screenshots',
    );
  });
}
