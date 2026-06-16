import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';

void main() {
  tearDown(() {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('consumer settings hide developer tools', (tester) async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = true;

    await pumpSettings(tester);

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('Export reflections'), findsOneWidget);
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
