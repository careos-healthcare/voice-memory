import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_app_bar_action.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_header_indicator.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PushedScreenShell shows sync indicator in AppBar actions', (
    tester,
  ) async {
    const syncState = BackgroundSyncState(pendingOutboxCount: 2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWithValue(
            const SyncStatusSnapshot(sync: syncState, isOnline: true),
          ),
        ],
        child: MaterialApp(
          home: PushedScreenShell(
            title: 'Settings',
            showBottomDone: false,
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.byType(SyncStatusAppBarAction), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('SyncStatusAppBarAction hides when sync is idle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWithValue(
            const SyncStatusSnapshot(
              sync: BackgroundSyncState(),
              isOnline: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Test'),
              actions: const [SyncStatusAppBarAction()],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SyncStatusAppBarAction), findsOneWidget);
    expect(find.byType(SyncStatusHeaderIndicator), findsNothing);
  });
}
