import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/llama_model_state.dart';
import 'package:voicememory_mobile/core/llm/llama_model_storage.dart';

void main() {
  late Directory temp;
  late LlamaModelStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('llama_storage_test_');
    storage = LlamaModelStorage(supportDirectory: () async => temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('uses safe application-support model paths', () async {
    expect(LlamaModelStorage.safeModelId('../Qwen 2.5'), 'qwen_2.5');
    expect(
      (await storage.installedFile('../Qwen 2.5')).path,
      '${temp.path}/llm_models/qwen_2.5/model.gguf',
    );
    expect(
      (await storage.partialFile('../Qwen 2.5')).path,
      '${temp.path}/llm_models/qwen_2.5/model.gguf.part',
    );
  });

  test('atomically round-trips state and manifest JSON', () async {
    const state = LlamaModelState(
      status: LlamaModelStatus.queued,
      optedIn: true,
      userPaused: false,
      progress: .25,
      downloadedBytes: 25,
      taskId: 'task',
      catalogRevision: 'revision',
    );

    await storage.writeState('model', state);
    await storage.writeManifest('model', {
      'modelId': 'model',
      'sha256': 'a' * 64,
    });

    expect((await storage.readState('model'))!.taskId, 'task');
    expect((await storage.readManifest('model'))!['modelId'], 'model');
    expect(
      await File('${temp.path}/llm_models/model/state.json.tmp').exists(),
      isFalse,
    );
  });

  test('promotes partial and replaces an existing model', () async {
    await storage.ensureModelDirectory('model');
    final installed = await storage.installedFile('model');
    final partial = await storage.partialFile('model');
    await installed.writeAsBytes([1]);
    await partial.writeAsBytes([2]);

    await storage.promotePartial('model');

    expect(await installed.readAsBytes(), [2]);
    expect(await partial.exists(), isFalse);
    expect(await File('${installed.path}.previous').exists(), isFalse);
  });

  test('corrupt JSON fails closed', () async {
    await storage.ensureModelDirectory('model');
    await (await storage.stateFile('model')).writeAsString('{broken');
    await (await storage.manifestFile('model')).writeAsString('[]');

    expect(await storage.readState('model'), isNull);
    expect(await storage.readManifest('model'), isNull);
  });
}
