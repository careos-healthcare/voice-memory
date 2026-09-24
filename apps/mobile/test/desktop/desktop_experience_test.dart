import 'dart:io';

import 'package:archiveme_mobile/desktop/archive_command_catalog.dart';
import 'package:archiveme_mobile/desktop/archive_command_palette.dart';
import 'package:archiveme_mobile/desktop/desktop_window_state.dart';
import 'package:archiveme_mobile/desktop/vault_sync_indicator.dart';
import 'package:archiveme_mobile/desktop/vault_sync_status.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window state round-trips and rejects tiny frames', () async {
    final dir = Directory.systemTemp.createTempSync('vm_window_state_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = DesktopWindowStateStore(File('${dir.path}/frame.json'));

    expect(await store.load(), isNull);
    await store.save(
      const DesktopWindowState(x: 12, y: 24, width: 1100, height: 760),
    );
    final loaded = await store.load();
    expect(loaded?.width, 1100);
    expect(loaded?.bounds.top, 24);
    expect(
      DesktopWindowState.fromJson({
        'x': 0,
        'y': 0,
        'width': 100,
        'height': 100,
      }),
      isNull,
    );
  });

  test('command filter matches titles and hides the rest', () {
    expect(ArchiveCommandCatalog.filter('').length, greaterThan(3));
    final typed = ArchiveCommandCatalog.filter('type');
    expect(typed.single.id, 'type_moment');
    expect(ArchiveCommandCatalog.filter('zzzz-nope'), isEmpty);
  });

  test('peer status stays off while direct peers are disabled', () {
    final status = VaultSyncStatus.compose(
      encryptionEnabled: true,
      p2pEnabled: false,
      sync: const SyncStatusSnapshot(
        sync: BackgroundSyncState(phase: BackgroundSyncPhase.cloudSync),
        isOnline: true,
      ),
      lastSyncedAt: DateTime.utc(2026, 9, 21, 15, 4),
    );

    expect(status.encryption, VaultEncryptionHealth.protected);
    expect(status.peers, PeerSyncStatus.off);
    expect(status.lastSyncedLabel, contains('Last synced'));
  });

  testWidgets('palette arrows change selection and enter runs the command', (
    tester,
  ) async {
    ArchiveCommand? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ArchiveCommandPalette(onSelected: (command) => chosen = command),
      ),
    );

    expect(find.byKey(const Key('archive_command_palette')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen?.id, 'type_moment');
  });

  testWidgets('Ctrl+K opens the palette from the host', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        navigatorKey: navigatorKey,
        home: CommandPaletteHost(
          navigatorKey: navigatorKey,
          child: const Scaffold(body: Text('ready')),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive_command_palette')), findsOneWidget);
    expect(find.text('New moment'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });

  testWidgets('vault indicator shows encryption, peers, and last sync', (
    tester,
  ) async {
    const status = VaultSyncStatus(
      encryption: VaultEncryptionHealth.protected,
      peers: PeerSyncStatus.off,
      lastSyncedAt: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VaultSyncStatusIndicator(status: status),
        ),
      ),
    );

    expect(find.byKey(const Key('vault_sync_status')), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('Encrypted'), findsOneWidget);
    expect(find.text('Peers off'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);
  });
}
