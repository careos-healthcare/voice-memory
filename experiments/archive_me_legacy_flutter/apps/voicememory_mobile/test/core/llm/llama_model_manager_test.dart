import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/llama_model_catalog.dart';
import 'package:voicememory_mobile/core/llm/llama_model_download_transport.dart';
import 'package:voicememory_mobile/core/llm/llama_model_manager.dart';
import 'package:voicememory_mobile/core/llm/llama_model_state.dart';
import 'package:voicememory_mobile/core/llm/llama_model_storage.dart';

void main() {
  late Directory temp;
  late LlamaModelStorage storage;
  late _FakeTransport transport;
  late _FakePlatformStorage platformStorage;
  late StreamController<List<ConnectivityResult>> connectivity;
  var wifi = true;
  var foregroundUnlocked = true;

  LlamaModelCatalog catalogFor(List<int> bytes, {String? hash}) =>
      LlamaModelCatalog.configured(
        LlamaModelDescriptor(
          id: LlamaModelCatalog.modelId,
          revision: LlamaModelCatalog.revision,
          url: Uri.parse('https://models.example/qwen.gguf'),
          sha256: hash ?? sha256.convert(bytes).toString(),
          expectedBytes: bytes.length,
          estimatedDisplaySize: '${bytes.length} bytes',
          license: 'Apache-2.0',
          attribution: 'Qwen',
        ),
      );

  Future<LlamaModelManager> managerFor(
    LlamaModelCatalog catalog, {
    _FakeTransport? managerTransport,
  }) async {
    final manager = LlamaModelManager(
      catalog: catalog,
      transport: managerTransport ?? transport,
      platformStorage: platformStorage,
      storage: storage,
      connectivityChanges: connectivity.stream,
      isWifi: () async => wifi,
      foregroundUnlocked: () async => foregroundUnlocked,
      clock: () => DateTime.utc(2026, 7, 23),
    );
    await manager.initialize();
    return manager;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('llama_manager_test_');
    storage = LlamaModelStorage(supportDirectory: () async => temp);
    transport = _FakeTransport();
    platformStorage = _FakePlatformStorage();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    wifi = true;
    foregroundUnlocked = true;
  });

  tearDown(() async {
    await connectivity.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('missing build configuration remains safely unconfigured', () async {
    final manager = await managerFor(
      LlamaModelCatalog.fromBuildEnvironment(
        url: '',
        sha256: '',
        expectedBytes: '',
      ),
    );

    await manager.optIn();

    expect(manager.state.status, LlamaModelStatus.notConfigured);
    expect(manager.state.optedIn, isFalse);
    expect(transport.enqueueCount, 0);
    expect(await Directory('${temp.path}/llm_models').exists(), isFalse);
    await manager.dispose();
  });

  test('opt-in is durable and concurrent calls enqueue once', () async {
    final manager = await managerFor(catalogFor([1, 2, 3]));

    await Future.wait([manager.optIn(), manager.optIn(), manager.optIn()]);
    await manager.optIn();

    expect(transport.enqueueCount, 1);
    expect(manager.state.optedIn, isTrue);
    expect(
      (await storage.readState(LlamaModelCatalog.modelId))!.optedIn,
      isTrue,
    );
    await manager.dispose();
  });

  test('reports progress and checks storage again before resume', () async {
    final manager = await managerFor(catalogFor([1, 2, 3, 4]));
    await manager.optIn();

    transport.emitProgress(.5, expectedBytes: 4);
    await _settle();
    expect(manager.state.status, LlamaModelStatus.downloading);
    expect(manager.state.progress, .5);
    expect(manager.state.downloadedBytes, 2);

    await manager.pause();
    final checksBeforeResume = platformStorage.availableCalls;
    await manager.resume();
    expect(platformStorage.availableCalls, checksBeforeResume + 1);
    expect(transport.pauseCount, 1);
    expect(transport.resumeCount, 1);
    await manager.dispose();
  });

  test('requires 2 GiB available before enqueue', () async {
    platformStorage.bytes = LlamaModelManager.minimumAvailableBytes - 1;
    final manager = await managerFor(catalogFor([1]));

    await manager.optIn();

    expect(manager.state.status, LlamaModelStatus.insufficientStorage);
    expect(manager.state.failure, LlamaModelFailure.insufficientStorage);
    expect(transport.enqueueCount, 0);
    await manager.dispose();
  });

  test('waits for Wi-Fi and resumes only while foreground unlocked', () async {
    wifi = false;
    final manager = await managerFor(catalogFor([1]));
    await manager.optIn();
    expect(manager.state.status, LlamaModelStatus.waitingForWifi);

    foregroundUnlocked = false;
    wifi = true;
    connectivity.add([ConnectivityResult.wifi]);
    await _settle();
    expect(transport.enqueueCount, 0);

    foregroundUnlocked = true;
    connectivity.add([ConnectivityResult.none]);
    connectivity.add([ConnectivityResult.wifi]);
    await _settle();
    expect(transport.enqueueCount, 1);
    await manager.dispose();
  });

  test('non-Wi-Fi pauses and user pause blocks automatic resume', () async {
    final manager = await managerFor(catalogFor([1, 2]));
    await manager.optIn();
    transport.emitStatus(LlamaModelDownloadStatus.running);
    connectivity.add([ConnectivityResult.mobile]);
    await _settle();
    expect(manager.state.status, LlamaModelStatus.waitingForWifi);
    expect(transport.pauseCount, 1);

    await manager.pause();
    wifi = true;
    connectivity.add([ConnectivityResult.wifi]);
    await _settle();
    expect(manager.state.userPaused, isTrue);
    expect(transport.resumeCount, 0);
    await manager.dispose();
  });

  test('restart reattaches durable task without duplicate enqueue', () async {
    final catalog = catalogFor([1, 2]);
    await storage.writeState(
      catalog.model!.id,
      LlamaModelState(
        status: LlamaModelStatus.queued,
        optedIn: true,
        userPaused: false,
        progress: 0,
        downloadedBytes: 0,
        taskId:
            'llama_model_${LlamaModelStorage.safeModelId(catalog.model!.id)}',
        catalogRevision: catalog.model!.revision,
      ),
    );
    transport.task = _task(
      catalog.model!,
      status: LlamaModelDownloadStatus.running,
    );

    final manager = await managerFor(catalog);

    expect(manager.state.status, LlamaModelStatus.downloading);
    expect(transport.enqueueCount, 0);
    await manager.dispose();
  });

  test('restart resumes a paused task only after storage check', () async {
    final catalog = catalogFor([1, 2]);
    await storage.writeState(
      catalog.model!.id,
      LlamaModelState(
        status: LlamaModelStatus.paused,
        optedIn: true,
        userPaused: false,
        progress: .5,
        downloadedBytes: 1,
        taskId:
            'llama_model_${LlamaModelStorage.safeModelId(catalog.model!.id)}',
        catalogRevision: catalog.model!.revision,
      ),
    );
    transport.task = _task(
      catalog.model!,
      status: LlamaModelDownloadStatus.paused,
    );

    final manager = await managerFor(catalog);

    expect(platformStorage.availableCalls, 1);
    expect(transport.resumeCount, 1);
    expect(transport.enqueueCount, 0);
    expect(manager.state.status, LlamaModelStatus.queued);
    await manager.dispose();
  });

  test('completion streams hash and atomically writes manifest', () async {
    final bytes = [104, 101, 108, 108, 111];
    final catalog = catalogFor(bytes);
    final manager = await managerFor(catalog);
    await manager.optIn();
    final partial = await storage.partialFile(catalog.model!.id);
    await partial.writeAsBytes(bytes);

    transport.emitStatus(LlamaModelDownloadStatus.complete);
    await _waitFor(() => manager.state.status == LlamaModelStatus.installed);

    expect(await partial.exists(), isFalse);
    expect(await File(manager.state.installedPath!).readAsBytes(), bytes);
    expect(manager.state.verifiedSha256, sha256.convert(bytes).toString());
    final manifest = await storage.readManifest(catalog.model!.id);
    expect(manifest!['catalogRevision'], catalog.model!.revision);
    expect(manifest['sha256'], catalog.model!.sha256);
    expect(platformStorage.excluded, isNotEmpty);
    await manager.dispose();
  });

  test('checksum and size mismatches delete partial files', () async {
    final expected = [1, 2, 3];
    var manager = await managerFor(catalogFor(expected));
    await manager.optIn();
    var partial = await storage.partialFile(manager.catalog.model!.id);
    await partial.writeAsBytes([3, 2, 1]);
    transport.emitStatus(LlamaModelDownloadStatus.complete);
    await _waitFor(
      () => manager.state.failure == LlamaModelFailure.checksumMismatch,
    );
    expect(await partial.exists(), isFalse);
    await manager.dispose();

    transport = _FakeTransport();
    manager = await managerFor(catalogFor(expected));
    await manager.optIn();
    partial = await storage.partialFile(manager.catalog.model!.id);
    await partial.writeAsBytes([1]);
    transport.emitStatus(LlamaModelDownloadStatus.complete);
    await _waitFor(
      () => manager.state.failure == LlamaModelFailure.expectedSizeMismatch,
    );
    expect(await partial.exists(), isFalse);
    await manager.dispose();
  });

  test('reported server size outside tolerance fails safely', () async {
    final manager = await managerFor(catalogFor([1, 2, 3]));
    await manager.optIn();

    transport.emitProgress(.1, expectedBytes: 99);
    await _waitFor(
      () => manager.state.failure == LlamaModelFailure.expectedSizeMismatch,
    );

    expect(transport.cancelCount, 1);
    await manager.dispose();
  });

  test('remove and opt-out cancel and clean artifacts', () async {
    final catalog = catalogFor([1]);
    final manager = await managerFor(catalog);
    await manager.optIn();
    final installed = await storage.installedFile(catalog.model!.id);
    await installed.writeAsBytes([1]);

    await manager.remove();
    expect(await installed.exists(), isFalse);
    expect(manager.state.optedIn, isTrue);

    await manager.optOut();
    expect(manager.state.optedIn, isFalse);
    expect(await Directory('${temp.path}/llm_models').exists(), isFalse);
    expect(transport.cancelCount, 2);
    await manager.dispose();
  });

  test('dispose cancels subscriptions and ignores later events', () async {
    final manager = await managerFor(catalogFor([1]));
    await manager.optIn();
    final before = manager.state;
    await manager.dispose();
    transport.emitProgress(.9);
    connectivity.add([ConnectivityResult.none]);
    await _settle();
    expect(identical(manager.state, before), isTrue);
    expect(transport.disposed, isTrue);
  });
}

LlamaModelDownloadTask _task(
  LlamaModelDescriptor model, {
  LlamaModelDownloadStatus? status,
}) => LlamaModelDownloadTask(
  taskId: 'llama_model_${LlamaModelStorage.safeModelId(model.id)}',
  group: LlamaModelManager.taskGroup,
  url: model.url,
  relativeDirectory: 'llm_models/${LlamaModelStorage.safeModelId(model.id)}',
  filename: 'model.gguf.part',
  metadata: {
    'modelId': model.id,
    'catalogRevision': model.revision,
    'sha256': model.sha256,
    'expectedBytes': '${model.expectedBytes}',
  },
  status: status,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await _settle();
  }
  fail('Condition was not reached.');
}

final class _FakePlatformStorage implements LlamaModelPlatformStorage {
  int bytes = LlamaModelManager.minimumAvailableBytes;
  int availableCalls = 0;
  final excluded = <String>[];

  @override
  Future<int> availableBytes(String path) async {
    availableCalls++;
    return bytes;
  }

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);
}

final class _FakeTransport implements LlamaModelDownloadTransport {
  final controller = StreamController<LlamaModelDownloadEvent>.broadcast();
  LlamaModelDownloadTask? task;
  int enqueueCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int cancelCount = 0;
  bool disposed = false;

  @override
  Stream<LlamaModelDownloadEvent> get events => controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<LlamaModelDownloadTask?> taskForId(String taskId) async =>
      task?.taskId == taskId ? task : null;

  @override
  Future<bool> enqueue(LlamaModelDownloadTask value) async {
    enqueueCount++;
    task = value;
    return true;
  }

  @override
  Future<bool> pause(LlamaModelDownloadTask value) async {
    pauseCount++;
    return true;
  }

  @override
  Future<bool> resume(LlamaModelDownloadTask value) async {
    resumeCount++;
    return true;
  }

  @override
  Future<bool> cancel(String taskId) async {
    cancelCount++;
    task = null;
    return true;
  }

  void emitProgress(double value, {int? expectedBytes}) {
    if (!disposed && task != null) {
      controller.add(
        LlamaModelDownloadProgressEvent(
          task!,
          progress: value,
          expectedBytes: expectedBytes,
        ),
      );
    }
  }

  void emitStatus(LlamaModelDownloadStatus status) {
    if (!disposed && task != null) {
      controller.add(LlamaModelDownloadStatusEvent(task!, status));
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}
