import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/config/production_navigation.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/account_privacy_controls_copy.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
    tempDir = Directory.systemTemp.createTempSync('vm_settings_widget_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          null,
        );
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

    expect(find.text(AccountPrivacyControlsCopy.privacyPolicy), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('settings_starting_context_tile')),
      find.byType(ListView),
      const Offset(0, -180),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('settings_starting_context_tile')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_theme_studio_tile')), findsOneWidget);
    expect(find.byKey(const Key('settings_persona_studio_tile')), findsNothing);
    expect(find.byKey(const Key('settings_browser_bridge_tile')), findsNothing);
    await tester.dragUntilVisible(
      find.text(ConsumerUiCopy.restorePurchases),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    expect(ProductionNavigation.isNavRouteVisible('/archive-export'), isFalse);
    expect(find.text(PrivacyDataControlsCopy.exportArchiveTitle), findsNothing);
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
