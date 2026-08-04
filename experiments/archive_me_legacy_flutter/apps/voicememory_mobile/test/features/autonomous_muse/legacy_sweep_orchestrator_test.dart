import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_store.dart';
import 'package:voicememory_mobile/features/autonomous_muse/legacy_sweep_orchestrator.dart';
import 'package:voicememory_mobile/features/autonomous_muse/semantic_bridge_builder.dart';
import 'package:voicememory_mobile/features/data_ingestion/legacy_ingestion_store.dart';
import 'package:voicememory_mobile/features/data_ingestion/markdown_vault_models.dart';
import 'package:voicememory_mobile/features/neural_sculptor/lora_adapter_trainer.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('processes no more than 50 notes and schedules the remainder', () async {
    final harness = await _Harness.create(noteCount: 51);
    addTearDown(harness.dispose);

    await harness.orchestrator.drainBatch();

    expect(harness.builder.builtIds, hasLength(50));
    expect(harness.store.undigestedNoteCount(), 1);
    expect(harness.scheduler.calls, 1);
    expect(harness.sleeps, [const Duration(seconds: 3)]);
    expect(harness.orchestrator.currentProgress.analyzedNodes, 50);
  });

  test('serious thermal pressure pauses without analyzing notes', () async {
    final harness = await _Harness.create(
      noteCount: 1,
      thermalState: NeuralThermalState.serious,
    );
    addTearDown(harness.dispose);

    await harness.orchestrator.drainBatch();

    expect(harness.builder.builtIds, isEmpty);
    expect(harness.store.undigestedNoteCount(), 1);
    expect(harness.sleeps, [const Duration(minutes: 2)]);
    expect(
      harness.orchestrator.currentProgress.status,
      LegacySweepStatus.pausedThermal,
    );
  });
}

final class _Harness {
  _Harness({
    required this.directory,
    required this.store,
    required this.museStore,
    required this.builder,
    required this.scheduler,
    required this.orchestrator,
    required this.sleeps,
  });

  final Directory directory;
  final LegacyIngestionStore store;
  final AutonomousMuseStore museStore;
  final _Builder builder;
  final _Scheduler scheduler;
  final LegacySweepOrchestrator orchestrator;
  final List<Duration> sleeps;

  static Future<_Harness> create({
    required int noteCount,
    NeuralThermalState thermalState = NeuralThermalState.nominal,
  }) async {
    final directory = await Directory.systemTemp.createTemp('legacy-sweep-');
    final codec = EncryptedSqliteTextCodec(
      () => Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
    );
    final vectorStore = await SqliteVecVectorStore.open(
      databasePath: '${directory.path}/vectors.sqlite3',
      dimensions: 4,
    );
    final store = await LegacyIngestionStore.open(
      databasePath: '${directory.path}/legacy.sqlite3',
      codec: codec,
      vectorStore: vectorStore,
    );
    store.writeBatch([
      for (var index = 0; index < noteCount; index++)
        PreparedMarkdownNote(note: _note(index), chunks: const []),
    ]);
    final museStore = AutonomousMuseStore.open(
      databasePath: '${directory.path}/muse.sqlite3',
      codec: codec,
    );
    final builder = _Builder();
    final scheduler = _Scheduler();
    final sleeps = <Duration>[];
    late final LegacySweepOrchestrator orchestrator;
    orchestrator = LegacySweepOrchestrator(
      legacyStore: store,
      museStore: museStore,
      bridgeBuilder: builder,
      scheduler: scheduler,
      hardwareProbe: _HardwareProbe(thermalState),
      sleeper: (duration) async => sleeps.add(duration),
      clock: () => DateTime.utc(2026, 7, 29, 6),
    );
    return _Harness(
      directory: directory,
      store: store,
      museStore: museStore,
      builder: builder,
      scheduler: scheduler,
      orchestrator: orchestrator,
      sleeps: sleeps,
    );
  }

  Future<void> dispose() async {
    await orchestrator.dispose();
    store.close();
    museStore.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  static ParsedMarkdownNote _note(int index) => ParsedMarkdownNote(
    id: 'note-$index',
    relativePath: '$index.md',
    title: 'Note $index',
    markdown: 'Note body $index',
    body: 'Note body $index',
    tags: const [],
    aliases: const [],
    links: const [],
    createdAt: DateTime.utc(2020),
    titleHash: 'title-$index',
    contentHash: 'content-$index',
  );
}

final class _Builder implements LegacyBridgeBuilding {
  final List<String> builtIds = [];

  @override
  Future<List<LegacyBridgeSuggestion>> build(LegacySweepNote note) async {
    builtIds.add(note.id);
    return const [];
  }

  @override
  Future<void> accept(String suggestionId) async {}

  @override
  void reject(String suggestionId) {}

  @override
  void defer(String suggestionId, DateTime until) {}
}

final class _Scheduler implements LegacySweepScheduler {
  int calls = 0;

  @override
  Future<void> schedule() async => calls++;
}

final class _HardwareProbe implements NeuralHardwareProbe {
  const _HardwareProbe(this.thermalState);

  final NeuralThermalState thermalState;

  @override
  Future<NeuralHardwareState> current() async => NeuralHardwareState(
    batteryPercent: 100,
    isCharging: true,
    thermalState: thermalState,
  );
}
