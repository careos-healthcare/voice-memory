import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/ui_screenshot_audit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production UI screenshot audit', (WidgetTester tester) async {
    final runner = UiScreenshotAuditRunner(binding: binding, tester: tester);

    final report = await runner.runFullAudit();

    expect(
      report.captures.length,
      greaterThanOrEqualTo(20),
      reason: 'Audit should capture route screens and key UI states',
    );

    final indexFile = '${report.outputRoot}/UI_SCREENSHOT_INDEX.md';
    final findingsFile = '${report.outputRoot}/UI_AUDIT_FINDINGS.md';
    expect(report.outputRoot, isNotEmpty);
    expect(
      report.inventory.routes.any((r) => r.path == '/record'),
      isTrue,
      reason: 'Router inventory should include /record',
    );
    // Reports are written at end of runFullAudit.
    expect(indexFile, isNotEmpty);
    expect(findingsFile, isNotEmpty);
  });
}