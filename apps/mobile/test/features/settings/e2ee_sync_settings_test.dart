import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enabling E2EE sync shows the passphrase to store', (tester) async {
    var enabled = false;
    String? stored;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: E2eeSyncSettings(
            readEnabled: () async => enabled,
            writeEnabled: (value) async => enabled = value,
            storePassphrase: (value) async => stored = value,
            generatePassphrase: () => 'store-me-safely',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_e2ee_sync')));
    await tester.pumpAndSettle();

    expect(find.text('Store your sync passphrase'), findsOneWidget);
    expect(find.text('store-me-safely'), findsOneWidget);

    await tester.tap(find.text("I've stored it"));
    await tester.pumpAndSettle();

    expect(stored, 'store-me-safely');
    expect(enabled, isTrue);
  });
}
