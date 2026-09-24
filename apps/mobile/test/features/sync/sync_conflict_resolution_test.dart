import 'package:archiveme_mobile/features/sync/application/conflict_line_diff.dart';
import 'package:archiveme_mobile/features/sync/application/conflict_resolution_store.dart';
import 'package:archiveme_mobile/features/sync/application/p2p_mesh_sync_engine.dart';
import 'package:archiveme_mobile/features/sync/application/sync_presence.dart';
import 'package:archiveme_mobile/features/sync/presentation/modals/conflict_resolution_modal.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/entry_sync_indicator.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_badge.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncStateProvider', () {
    test('badge state follows reachability, mesh, and conflict', () async {
      final engine = P2pMeshSyncEngine();
      final store = MemoryConflictResolutionStore();
      final container = ProviderContainer(
        overrides: [
          p2pMeshSyncEngineProvider.overrideWithValue(engine),
          conflictResolutionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(syncStateProvider.notifier);

      expect(container.read(syncStateProvider).label, 'Local Only');

      notifier.reportNetwork(cloudReachable: true, meshHandshake: false);
      expect(container.read(syncStateProvider).label, 'Synced (Cloud)');

      notifier.reportNetwork(cloudReachable: true, meshHandshake: true);
      expect(container.read(syncStateProvider).label, 'Synced (Mesh/Cloud)');

      notifier.reportNetwork(cloudReachable: false, meshHandshake: true);
      expect(container.read(syncStateProvider).label, 'Synced (Mesh)');

      notifier.stageConflict(entryId: 'e1', remoteTranscript: 'remote line');
      expect(container.read(syncStateProvider).label, 'Conflict Detected');

      notifier.reportNetwork(cloudReachable: false, meshHandshake: false);
      expect(container.read(syncStateProvider).label, 'Conflict Detected');

      await notifier.resolve(
        const ConflictDecision(
          entryId: 'e1',
          choice: ConflictChoice.useLocal,
          resolvedText: 'local line',
        ),
      );

      expect(engine.isConflictDismissed('e1'), isTrue);
      expect((await store.read('e1'))?.resolvedText, 'local line');
      expect(container.read(syncStateProvider).label, 'Local Only');
    });
  });

  group('line diff', () {
    test('highlights additions and deletions and can drop a line', () {
      final rows = buildLineDiff('alpha\nbeta', 'alpha\ngamma');
      expect(rows.map((row) => row.kind).toList(), [
        DiffLineKind.unchanged,
        DiffLineKind.removed,
        DiffLineKind.added,
      ]);
      expect(combineSelectedLines(rows, [true, true]), 'alpha\nbeta\ngamma');
      expect(combineSelectedLines(rows, [false, true]), 'alpha\ngamma');
    });
  });

  group('SqliteConflictResolutionStore', () {
    test('persists the chosen transcript', () async {
      configureSqliteTestFfi();
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final store = SqliteConflictResolutionStore(db);
      await store.save(
        const ConflictDecision(
          entryId: 'e1',
          choice: ConflictChoice.combineBoth,
          resolvedText: 'alpha\nbeta',
        ),
      );
      final saved = await store.read('e1');
      expect(saved?.choice, ConflictChoice.combineBoth);
      expect(saved?.resolvedText, 'alpha\nbeta');
    });
  });

  testWidgets('header badge updates when network state changes', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SyncStatusBadgeSlot()),
        ),
      ),
    );
    expect(find.text('Local Only'), findsOneWidget);

    container
        .read(syncStateProvider.notifier)
        .reportNetwork(
          cloudReachable: true,
          meshHandshake: true,
        );
    await tester.pump();
    expect(find.text('Synced (Mesh/Cloud)'), findsOneWidget);

    container
        .read(syncStateProvider.notifier)
        .stageConflict(
          entryId: 'e1',
          remoteTranscript: 'incoming',
        );
    await tester.pump();
    expect(find.text('Conflict Detected'), findsOneWidget);
  });

  testWidgets('conflicting entry opens the diff and a choice clears it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    final engine = P2pMeshSyncEngine();
    final store = MemoryConflictResolutionStore();
    final container = ProviderContainer(
      overrides: [
        p2pMeshSyncEngineProvider.overrideWithValue(engine),
        conflictResolutionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider.notifier)
      ..reportNetwork(cloudReachable: true, meshHandshake: true)
      ..stageConflict(entryId: 'e1', remoteTranscript: 'alpha\ngamma');

    final entry = _entry().copyWith(
      transcript: 'alpha\nbeta',
      syncStatus: SyncStatus.conflict,
    );
    var opened = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SyncStatusBadgeSlot(),
                EntrySyncIndicator(status: entry.syncStatus),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      openEntryRespectingConflict(
                        context: context,
                        entry: entry,
                        onOpen: () => opened++,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Conflict'), findsOneWidget);
    expect(find.text('Conflict Detected'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.byKey(const Key('conflict_resolution_modal')), findsOneWidget);
    expect(find.text('beta'), findsWidgets);
    expect(find.text('gamma'), findsWidgets);

    await tester.tap(find.byKey(const Key('conflict_line_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('conflict_combine')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conflict_resolution_modal')), findsNothing);
    expect(find.text('Conflict Detected'), findsNothing);
    expect(find.text('Synced (Mesh/Cloud)'), findsOneWidget);
    expect(engine.isConflictDismissed('e1'), isTrue);
    expect((await store.read('e1'))?.resolvedText, 'alpha\ngamma');
  });

  testWidgets('Use Local keeps the on-device transcript', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    ConflictDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                decision = await ConflictResolutionModal.show(
                  context,
                  entryId: 'e1',
                  localText: 'keep me',
                  remoteText: 'drop me',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conflict_use_local')));
    await tester.pumpAndSettle();
    expect(decision?.choice, ConflictChoice.useLocal);
    expect(decision?.resolvedText, 'keep me');
  });
}

JournalEntry _entry() {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 6),
    transcript: 'alpha',
    durationSeconds: 0,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}
