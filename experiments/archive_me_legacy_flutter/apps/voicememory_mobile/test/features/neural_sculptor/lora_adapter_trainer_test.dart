import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/neural_sculptor/lora_adapter_trainer.dart';
import 'package:voicememory_mobile/features/neural_sculptor/neural_dataset_builder.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('fails closed when native trainer capability is unavailable', () async {
    final harness = await _TrainerHarness.create();
    addTearDown(harness.dispose);
    final trainer = LoRAAdapterTrainer(datasetBuilder: harness.builder);

    await trainer.start(harness.configuration);

    expect(trainer.state.status, LoRATrainingStatus.unsupported);
    expect(harness.trainingPlaintextExists(), isFalse);
    await trainer.dispose();
  });

  test('pauses on thermal elevation, resumes, and cleans dataset', () async {
    final harness = await _TrainerHarness.create();
    addTearDown(harness.dispose);
    final backend = _FakeTrainingBackend();
    final hardware = _SequenceHardwareProbe([_safe, _hot, _safe, _safe]);
    final trainer = LoRAAdapterTrainer(
      datasetBuilder: harness.builder,
      backend: backend,
      hardwareProbe: hardware,
      pollInterval: Duration.zero,
    );

    await trainer.start(harness.configuration);

    expect(trainer.state.status, LoRATrainingStatus.completed);
    expect(backend.pauseCount, 1);
    expect(backend.resumeCount, 1);
    expect(trainer.state.lossHistory, isNotEmpty);
    expect(harness.trainingPlaintextExists(), isFalse);
    await trainer.dispose();
  });
}

const _safe = NeuralHardwareState(
  batteryPercent: 80,
  isCharging: true,
  thermalState: NeuralThermalState.nominal,
);
const _hot = NeuralHardwareState(
  batteryPercent: 80,
  isCharging: true,
  thermalState: NeuralThermalState.serious,
);

final class _SequenceHardwareProbe implements NeuralHardwareProbe {
  _SequenceHardwareProbe(this.values);
  final List<NeuralHardwareState> values;
  var _index = 0;

  @override
  Future<NeuralHardwareState> current() async {
    final index = _index < values.length ? _index++ : values.length - 1;
    return values[index];
  }
}

final class _FakeTrainingBackend implements NativeLoRATrainingBackend {
  var pauseCount = 0;
  var resumeCount = 0;
  Directory? output;

  @override
  Future<LoRATrainerCapability> capability() async =>
      const LoRATrainerCapability(
        available: true,
        backend: 'test-native',
        reason: '',
        abiVersion: 1,
      );

  @override
  Future<String> start({
    required String datasetPath,
    required LoRATrainingConfiguration configuration,
  }) async {
    expect(await File(datasetPath).exists(), isTrue);
    output = configuration.outputDirectory;
    return 'job-1';
  }

  @override
  Future<NativeLoRATrainingProgress> poll(String jobId) async {
    final safe = File('${output!.path}/adapter.safetensors');
    final gguf = File('${output!.path}/adapter.gguf');
    await safe.writeAsBytes([1, 2, 3]);
    await gguf.writeAsBytes([4, 5, 6]);
    return NativeLoRATrainingProgress(
      epoch: 1,
      totalEpochs: 1,
      tokensProcessed: 42,
      loss: .25,
      finished: true,
      safetensorsPath: safe.path,
      ggufAdapterPath: gguf.path,
    );
  }

  @override
  Future<void> pause(String jobId) async => pauseCount++;

  @override
  Future<void> resume(String jobId) async => resumeCount++;

  @override
  Future<void> cancel(String jobId) async {}
}

final class _TrainerHarness {
  _TrainerHarness({
    required this.root,
    required this.builder,
    required this.configuration,
    required this.graphStore,
    required this.clusterStore,
  });

  final Directory root;
  final NeuralDatasetBuilder builder;
  final LoRATrainingConfiguration configuration;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;

  static Future<_TrainerHarness> create() async {
    final root = await Directory.systemTemp.createTemp('neural_trainer_test_');
    final key = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.filled(32, 7),
    );
    final journal = await JournalStore.open(
      '${root.path}/journal.json',
      encryptAtRest: false,
    );
    await journal.save(
      JournalEntry(
        id: 'training-entry',
        createdAt: DateTime.utc(2026),
        transcript: 'I kept moving and learned from the attempt.',
        durationSeconds: 10,
        reflection: const Reflection(
          mood: 'steady',
          emotionalIntensity: 5,
          recurringThemes: ['learning'],
          exactLanguagePattern: 'kept moving',
          concreteObservation: 'I kept moving.',
          repeatedSignal: 'moving',
        ),
      ),
    );
    final graphStore = PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: key,
      ),
    );
    final clusterStore = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/clusters.enc'),
        keyStore: key,
      ),
    );
    final builder = NeuralDatasetBuilder(
      journalStore: journal,
      graphStore: graphStore,
      clusterStore: clusterStore,
      encryptedStore: EncryptedJsonFileStore(
        file: File('${root.path}/dataset.enc'),
        keyStore: key,
      ),
      temporaryDirectory: () async => root,
    );
    await builder.build();
    final model = File('${root.path}/model.gguf');
    await model.writeAsBytes([1]);
    return _TrainerHarness(
      root: root,
      builder: builder,
      configuration: LoRATrainingConfiguration(
        baseModelPath: model.path,
        baseModelSha256: 'abc123',
        outputDirectory: Directory('${root.path}/output'),
        epochs: 1,
      ),
      graphStore: graphStore,
      clusterStore: clusterStore,
    );
  }

  bool trainingPlaintextExists() => Directory(
    '${root.path}/${NeuralDatasetBuilder.temporaryDirectoryName}',
  ).existsSync();

  Future<void> dispose() async {
    clusterStore.dispose();
    await graphStore.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
