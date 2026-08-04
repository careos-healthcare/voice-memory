import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_event_engine.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_models.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('matches exact triggers and deduplicates event ids', () async {
    final harness = _Harness();
    var executions = 0;
    final recipe = CatalystRecipe(
      id: 'graph-only',
      name: 'Graph only',
      trigger: const CatalystTrigger(CatalystTriggerKind.graphChanged),
      actions: const [
        CatalystAction(id: 'cluster', kind: CatalystActionKind.rebuildClusters),
      ],
    );
    await harness.store.saveRecipe(recipe);
    final engine = CatalystEventEngine(
      store: harness.store,
      isForegroundUnlocked: () => true,
      execute: (recipe, event, {dryRun = false}) async {
        executions++;
        return _run(recipe, event);
      },
    );
    try {
      await engine.emit(CatalystTriggerKind.journalChanged, id: 'journal-1');
      await engine.emit(CatalystTriggerKind.graphChanged, id: 'graph-1');
      await engine.emit(CatalystTriggerKind.graphChanged, id: 'graph-1');

      expect(executions, 1);
      expect((await harness.store.read()).runs, hasLength(1));
    } finally {
      await engine.dispose();
      await harness.dispose();
    }
  });

  test(
    'queues locked and background events then drains in foreground',
    () async {
      final harness = _Harness();
      var foreground = false;
      var executions = 0;
      await harness.store.saveRecipe(
        CatalystRecipe(
          id: 'schedule',
          name: 'Schedule',
          trigger: const CatalystTrigger(CatalystTriggerKind.scheduleTick),
          actions: const [
            CatalystAction(id: 'muse', kind: CatalystActionKind.museSweep),
          ],
        ),
      );
      final engine = CatalystEventEngine(
        store: harness.store,
        isForegroundUnlocked: () => foreground,
        execute: (recipe, event, {dryRun = false}) async {
          executions++;
          return _run(recipe, event);
        },
      );
      try {
        await engine.emit(
          CatalystTriggerKind.scheduleTick,
          id: 'tick-1',
          background: true,
        );
        expect((await harness.store.read()).pendingEvents, hasLength(1));
        foreground = true;
        await engine.resume();
        expect(executions, 1);
        expect((await harness.store.read()).pendingEvents, isEmpty);
      } finally {
        await engine.dispose();
        await harness.dispose();
      }
    },
  );
}

CatalystRunLog _run(CatalystRecipe recipe, CatalystEvent event) =>
    CatalystRunLog(
      id: '${recipe.id}:${event.id}',
      recipeId: recipe.id,
      eventId: event.id,
      status: CatalystRunStatus.succeeded,
      startedAt: event.occurredAt,
      finishedAt: event.occurredAt,
      completedActionIds: recipe.actions.map((item) => item.id).toList(),
    );

final class _Harness {
  _Harness()
    : root = Directory.systemTemp.createTempSync('catalyst-event-'),
      keyStore = InMemoryPrivateDataEncryptionKeyStore() {
    store = CatalystStore(
      EncryptedJsonFileStore(
        file: File('${root.path}/state.enc'),
        keyStore: keyStore,
      ),
    );
  }

  final Directory root;
  final InMemoryPrivateDataEncryptionKeyStore keyStore;
  late final CatalystStore store;

  Future<void> dispose() async {
    await store.dispose();
    root.deleteSync(recursive: true);
  }
}
