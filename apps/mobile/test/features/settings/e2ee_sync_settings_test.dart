import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/settings/views/e2ee_setup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enabling E2EE sync shows the passphrase to store', (
    tester,
  ) async {
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

    expect(find.text('Sync passphrase'), findsOneWidget);
    expect(find.text(E2eeSetupView.warning), findsOneWidget);
    expect(find.text('store-me-safely'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('e2ee_setup_continue')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('e2ee_stored_checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('e2ee_setup_continue')));
    await tester.pumpAndSettle();

    expect(stored, 'store-me-safely');
    expect(enabled, isTrue);
  });

  testWidgets('an existing passphrase can be entered after it is confirmed', (
    tester,
  ) async {
    String? stored;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: E2eeSyncSettings(
            readEnabled: () async => false,
            writeEnabled: (_) async {},
            storePassphrase: (value) async => stored = value,
            generatePassphrase: () => 'generated-not-used',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_e2ee_sync')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('e2ee_enter_passphrase')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('e2ee_passphrase_input')),
      'already-written-down',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('e2ee_setup_continue')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('e2ee_stored_checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('e2ee_setup_continue')));
    await tester.pumpAndSettle();
    expect(stored, 'already-written-down');
  });
}
