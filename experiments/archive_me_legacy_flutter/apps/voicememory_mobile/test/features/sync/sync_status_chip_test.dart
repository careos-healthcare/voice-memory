import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_status_chip.dart';

void main() {
  for (final testCase in <(EncryptedSyncState, String)>[
    (EncryptedSyncState.offline, 'Offline'),
    (EncryptedSyncState.syncing, 'Syncing'),
    (EncryptedSyncState.upToDate, 'Up to date'),
  ]) {
    testWidgets('sync status chip represents ${testCase.$2}', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusChip(
              state: testCase.$1,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );
      expect(find.text(testCase.$2), findsOneWidget);
      expect(
        find.bySemanticsLabel('Encrypted sync status: ${testCase.$2}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('memory-graph-sync-status-chip')));
      await tester.pump();
      expect(pressed, isTrue);
    });
  }
}
