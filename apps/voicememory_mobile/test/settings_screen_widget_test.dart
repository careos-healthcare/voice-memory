
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'support/test_storage_sandbox.dart';

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('consumer settings hide developer tools', (tester) async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = true;

    await pumpSettings(tester);

    expect(find.text('Privacy'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text(ConsumerUiCopy.restorePurchases),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    await tester.dragUntilVisible(
      find.text(PrivacyDataControlsCopy.exportArchiveTitle),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(
      find.text(PrivacyDataControlsCopy.exportArchiveTitle),
      findsOneWidget,
    );
    expect(find.text('Developer'), findsNothing);
    expect(find.text('RevenueCat verification'), findsNothing);
    expect(find.text('API base URL'), findsNothing);
  });

  testWidgets('developer diagnostics when gate is open', (tester) async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.applyLoadedUnlock(true);

    await pumpSettings(tester);

    // The Memory section made the list taller — scroll until the
    // developer tile at the bottom is visible.
    await tester.dragUntilVisible(
      find.text('Developer diagnostics'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text('Developer diagnostics'), findsOneWidget);
    expect(find.text('RevenueCat verification'), findsNothing);
  });
}
