import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _resetServices() async {
  await AppServices.resetForTest(
    journalPath: '${Directory.systemTemp.createTempSync('vm_account_').path}/journal.json',
    prefsPath: '${Directory.systemTemp.createTempSync('vm_account_prefs_').path}/prefs.json',
  );
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  testWidgets('account title is ArchiveMe account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.pump();

    expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);
    expect(find.text('VoiceMemory account'), findsNothing);
  });

  testWidgets('sync action respects backend configuration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.pumpAndSettle();

    if (AppConfig.isBackendConfigured) {
      expect(find.text('Sync now'), findsOneWidget);
    } else {
      expect(find.text('Sync now'), findsNothing);
      expect(
        find.text(ConsumerUiCopy.syncNotAvailableTestFlight),
        findsOneWidget,
      );
    }
  });
}
