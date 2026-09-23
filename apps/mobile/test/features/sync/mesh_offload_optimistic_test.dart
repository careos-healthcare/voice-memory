import 'package:archiveme_mobile/features/sync/mesh_offload_optimistic.dart';
import 'package:archiveme_mobile/features/sync/mesh_offload_sync_service.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/mesh_offload_save_row.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:archiveme_mobile/widgets/archive/archive_change_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MeshOffloadOptimisticCoordinator coordinator;

  setUp(() {
    coordinator = MeshOffloadOptimisticCoordinator();
  });

  tearDown(MeshOffloadOptimisticCoordinator.instance.resetForTest);

  test('shows the save before mesh settle starts', () async {
    final pending = coordinator.beginArchiveSave(
      id: 'rent',
      preview: 'Rent is due Friday',
      skeletonHold: Duration.zero,
    );

    expect(coordinator.saves.single.phase, MeshOffloadSavePhase.optimistic);
    expect(coordinator.saves.single.preview, 'Rent is due Friday');

    await pending;
    expect(coordinator.saves.single.phase, MeshOffloadSavePhase.settled);
    expect(
      coordinator.saves.single.settledLabel,
      MeshOffloadOptimisticCoordinator.savedOnDeviceLabel,
    );
  });

  test('keeps the local words when a peer copy differs', () {
    final settle = MeshOffloadConflictSettle.resolve(
      localPreview: 'Rent is due Friday',
      remotePreview: 'Rent was paid',
    );

    expect(settle.merged, isTrue);
    expect(settle.preview, 'Rent is due Friday');
  });

  testWidgets('covers mesh settle with a skeleton, then shows the save', (
    tester,
  ) async {
    final crypto = SyncCrypto(List<int>.filled(32, 4));
    final mesh = MeshOffloadSyncService(crypto: crypto);
    var conflictsResolved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: coordinator,
            builder: (context, _) {
              return MeshOffloadOptimisticList(saves: coordinator.saves);
            },
          ),
        ),
      ),
    );

    final pending = coordinator.beginArchiveSave(
      id: 'rent',
      preview: 'Rent is due Friday',
      skeletonHold: const Duration(milliseconds: 40),
      mesh: mesh,
      remotePreview: 'Rent was paid',
      resolveConflicts: () async {
        conflictsResolved = true;
      },
    );

    await tester.pump();
    expect(find.text('Rent is due Friday'), findsOneWidget);
    expect(find.text('Saving'), findsOneWidget);

    await tester.pump(Duration.zero);
    expect(find.byKey(const Key('mesh_offload_skeleton_rent')), findsOneWidget);
    expect(find.bySemanticsLabel('Mesh sync settling'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));
    await pending;
    await tester.pump();

    expect(conflictsResolved, isTrue);
    expect(mesh.pending, isNotEmpty);
    expect(find.byKey(const Key('mesh_offload_skeleton_rent')), findsNothing);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('Rent is due Friday'), findsOneWidget);
  });

  testWidgets('archive feed paints the save before the skeleton clears', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchiveChangeFeed(entries: []),
          ),
        ),
      ),
    );

    final pending = MeshOffloadOptimisticCoordinator.instance.beginArchiveSave(
      id: 'rent',
      preview: 'Rent is due Friday',
      skeletonHold: const Duration(milliseconds: 30),
    );
    await tester.pump();
    expect(find.text('Rent is due Friday'), findsOneWidget);
    expect(find.text('Saving'), findsOneWidget);

    await tester.pump(Duration.zero);
    expect(find.byKey(const Key('mesh_offload_skeleton_rent')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 30));
    await pending;
    await tester.pump();

    expect(find.byKey(const Key('mesh_offload_skeleton_rent')), findsNothing);
    expect(find.text('Saved on this device'), findsOneWidget);
  });
}
