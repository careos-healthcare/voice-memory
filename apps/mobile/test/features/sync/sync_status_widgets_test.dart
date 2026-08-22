import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_banner.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_header_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SyncStatusBanner shows pending upload count and progress', (
    tester,
  ) async {
    const syncState = BackgroundSyncState(
      phase: BackgroundSyncPhase.outboxDrain,
      queuedEntryCount: 4,
      pendingOutboxCount: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SyncStatusBanner(
            status: SyncStatusSnapshot(
              sync: syncState,
              isOnline: true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Uploading encrypted changes'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('SyncStatusHeaderIndicator shows offline badge count', (
    tester,
  ) async {
    const status = SyncStatusSnapshot(
      sync: BackgroundSyncState(pendingOutboxCount: 3),
      isOnline: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SyncStatusHeaderIndicator(status: status),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
