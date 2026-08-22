import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/screenshot_capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture full app screenshots', (WidgetTester tester) async {
    await ScreenshotCaptureRunner.prepareAppForScreenshots();

    final runner = ScreenshotCaptureRunner(binding: binding, tester: tester);

    final report = await runner.runAll();
    expect(
      report.totalScreenshots,
      greaterThan(0),
      reason: 'Expected at least one PNG (including error_*.png)',
    );
  });
}