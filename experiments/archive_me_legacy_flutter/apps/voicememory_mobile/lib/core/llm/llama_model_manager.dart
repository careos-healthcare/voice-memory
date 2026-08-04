import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';

import 'background_downloader_llama_transport.dart';
import 'llama_model_catalog.dart';
import 'llama_model_download_transport.dart';
import 'llama_model_state.dart';
import 'llama_model_storage.dart';

typedef ForegroundUnlockedCheck = Future<bool> Function();
typedef WifiCheck = Future<bool> Function();

final class LlamaModelManager {
  LlamaModelManager({
    required this.catalog,
    required LlamaModelDownloadTransport transport,
    required LlamaModelPlatformStorage platformStorage,
    required LlamaModelStorage storage,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    WifiCheck? isWifi,
    ForegroundUnlockedCheck? foregroundUnlocked,
    DateTime Function()? clock,
  }) : // Public parameter names intentionally differ from private fields.
       // ignore: prefer_initializing_formals
       _transport = transport,
       // ignore: prefer_initializing_formals
       _platformStorage = platformStorage,
       // ignore: prefer_initializing_formals
       _storage = storage,
       _connectivityChanges =
           connectivityChanges ?? Connectivity().onConnectivityChanged,
       _isWifi =
           isWifi ??
           (() async => (await Connectivity().checkConnectivity()).contains(
             ConnectivityResult.wifi,
           )),
       _foregroundUnlocked = foregroundUnlocked ?? (() async => true),
       _clock = clock ?? DateTime.now,
       _state = LlamaModelState(
         status: catalog.state == LlamaModelCatalogState.configured
             ? LlamaModelStatus.notOptedIn
             : LlamaModelStatus.notConfigured,
         optedIn: false,
         userPaused: false,
         progress: 0,
         downloadedBytes: 0,
       );

  static const minimumAvailableBytes =
      NativeLlamaModelPlatformStorage.minimumAvailableBytes;
  static const taskGroup = BackgroundDownloaderLlamaTransport.modelGroup;

  final LlamaModelCatalog catalog;
  final LlamaModelDownloadTransport _transport;
  final LlamaModelPlatformStorage _platformStorage;
  final LlamaModelStorage _storage;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final WifiCheck _isWifi;
  final ForegroundUnlockedCheck _foregroundUnlocked;
  final DateTime Function() _clock;
  final StreamController<LlamaModelState> _states =
      StreamController<LlamaModelState>.broadcast(sync: true);
  final Map<String, Future<void>> _flights = {};

  LlamaModelState _state;
  Future<void> _operationTail = Future<void>.value();
  StreamSubscription<LlamaModelDownloadEvent>? _downloadSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _initialized = false;
  bool _disposed = false;
  bool _pausedForWifi = false;
  bool _directoryPrepared = false;

  LlamaModelState get state => _state;
  LlamaModelSnapshot get snapshot => _state;
  Stream<LlamaModelState> get states => _states.stream;
  Stream<LlamaModelSnapshot> get snapshots => states;

  LlamaModelDescriptor? get _model => catalog.model;
  String get _modelId => _model?.id ?? LlamaModelCatalog.modelId;
  String get _taskId =>
      'llama_model_${LlamaModelStorage.safeModelId(_modelId)}';

  Future<void> initialize() => _singleFlight('initialize', () async {
    if (_initialized || _disposed) return;
    _initialized = true;
    if (_model == null) {
      _emit(_state.copyWith(status: LlamaModelStatus.notConfigured));
      return;
    }

    final persisted = await _storage.readState(_modelId);
    if (persisted != null) {
      _emit(
        persisted.copyWith(
          status: persisted.optedIn
              ? LlamaModelStatus.queued
              : LlamaModelStatus.notOptedIn,
          taskId: _taskId,
          catalogRevision: _model!.revision,
          clearFailure: true,
          clearInstallation:
              persisted.catalogRevision != _model!.revision ||
              persisted.verifiedSha256 != _model!.sha256,
        ),
      );
    }

    _downloadSubscription = _transport.events.listen(_onDownloadEvent);
    _connectivitySubscription = _connectivityChanges.listen(
      _onConnectivityChanged,
    );
    try {
      await _transport.initialize();
      await _prepareDirectory();
    } on Object {
      await _fail(LlamaModelFailure.storageProbe);
      return;
    }

    if (await _hasValidInstallation()) {
      final installed = await _storage.installedFile(_modelId);
      _emit(
        _state.copyWith(
          status: LlamaModelStatus.installed,
          progress: 1,
          downloadedBytes: _model!.expectedBytes,
          installedPath: installed.path,
          verifiedSha256: _model!.sha256,
          clearFailure: true,
        ),
      );
      await _persist();
      return;
    }
    await _removeInvalidInstallation();

    final partial = await _storage.partialFile(_modelId);
    final task = await _transport.taskForId(_taskId);
    if (task != null && _isManagerTask(task)) {
      if (!_state.optedIn) {
        await _transport.cancel(_taskId);
        final partial = await _storage.partialFile(_modelId);
        if (await partial.exists()) await partial.delete();
        _emit(_state.copyWith(status: LlamaModelStatus.notOptedIn));
      } else if (_state.userPaused) {
        await _transport.pause(task);
        _emit(_state.copyWith(status: LlamaModelStatus.paused));
      } else if (!await _isWifi()) {
        _pausedForWifi = true;
        await _transport.pause(task);
        _emit(_state.copyWith(status: LlamaModelStatus.waitingForWifi));
      } else {
        switch (task.status) {
          case LlamaModelDownloadStatus.complete:
            await _verifyAndPromote();
            return;
          case LlamaModelDownloadStatus.failed:
          case LlamaModelDownloadStatus.canceled:
            await _transport.cancel(_taskId);
            if (await partial.exists()) await partial.delete();
            await _attemptStartOrWait();
            return;
          case LlamaModelDownloadStatus.paused:
            await _attemptStartOrWait();
            return;
          case LlamaModelDownloadStatus.enqueued:
          case LlamaModelDownloadStatus.waitingToRetry:
            _emit(_state.copyWith(status: LlamaModelStatus.queued));
          case LlamaModelDownloadStatus.running:
          case null:
            _emit(_state.copyWith(status: LlamaModelStatus.downloading));
        }
      }
      await _persist();
      return;
    }

    if (await partial.exists()) await partial.delete();
    if (_state.optedIn && !_state.userPaused) await _attemptStartOrWait();
  });

  Future<void> optIn() => _singleFlight('intent', () async {
    _checkReady();
    if (_model == null) return;
    _emit(
      _state.copyWith(
        optedIn: true,
        userPaused: false,
        taskId: _taskId,
        catalogRevision: _model!.revision,
        clearFailure: true,
      ),
    );
    await _persist();
    await _attemptStartOrWait();
  });

  Future<void> pause() => _singleFlight('intent', () async {
    _checkReady();
    if (_model == null || !_state.optedIn) return;
    final task = await _transport.taskForId(_taskId);
    if (task != null && _isManagerTask(task)) await _transport.pause(task);
    _pausedForWifi = false;
    _emit(_state.copyWith(status: LlamaModelStatus.paused, userPaused: true));
    await _persist();
  });

  Future<void> resume() => _singleFlight('intent', () async {
    _checkReady();
    if (_model == null || !_state.optedIn) return;
    _emit(_state.copyWith(userPaused: false, clearFailure: true));
    await _persist();
    await _attemptStartOrWait();
  });

  Future<void> cancel() => _singleFlight('intent', () async {
    _checkReady();
    if (_model == null) return;
    await _transport.cancel(_taskId);
    final partial = await _storage.partialFile(_modelId);
    if (await partial.exists()) await partial.delete();
    _emit(
      _state.copyWith(
        status: _state.optedIn
            ? LlamaModelStatus.paused
            : LlamaModelStatus.notOptedIn,
        userPaused: _state.optedIn,
        progress: 0,
        downloadedBytes: 0,
      ),
    );
    await _persist();
  });

  Future<void> optOut() => _singleFlight('remove', () async {
    if (_model != null) await _transport.cancel(_taskId);
    await _storage.removeAll();
    _directoryPrepared = false;
    _pausedForWifi = false;
    _emit(
      LlamaModelState(
        status: _model == null
            ? LlamaModelStatus.notConfigured
            : LlamaModelStatus.notOptedIn,
        optedIn: false,
        userPaused: false,
        progress: 0,
        downloadedBytes: 0,
      ),
    );
  });

  Future<void> remove() => _singleFlight('remove', () async {
    if (_model == null) return;
    await _transport.cancel(_taskId);
    await _storage.removeModel(_modelId);
    _directoryPrepared = false;
    _emit(
      LlamaModelState(
        status: _state.optedIn
            ? LlamaModelStatus.paused
            : LlamaModelStatus.notOptedIn,
        optedIn: _state.optedIn,
        userPaused: _state.optedIn,
        progress: 0,
        downloadedBytes: 0,
        taskId: _taskId,
        catalogRevision: _model!.revision,
      ),
    );
    await _prepareDirectory();
    await _persist();
  });

  Future<void> _attemptStartOrWait() async {
    if (_disposed || _model == null || !_state.optedIn) return;
    if (_state.userPaused) {
      _emit(_state.copyWith(status: LlamaModelStatus.paused));
      return;
    }
    if (!await _foregroundUnlocked()) return;
    if (!await _isWifi()) {
      _pausedForWifi = true;
      _emit(_state.copyWith(status: LlamaModelStatus.waitingForWifi));
      await _persist();
      return;
    }

    _emit(_state.copyWith(status: LlamaModelStatus.checkingStorage));
    try {
      await _prepareDirectory();
      final directory = await _storage.modelDirectory(_modelId);
      if (await _platformStorage.availableBytes(directory.path) <
          minimumAvailableBytes) {
        await _fail(
          LlamaModelFailure.insufficientStorage,
          status: LlamaModelStatus.insufficientStorage,
        );
        return;
      }
    } on Object {
      await _fail(LlamaModelFailure.storageProbe);
      return;
    }
    if (!await _isWifi()) {
      _pausedForWifi = true;
      _emit(_state.copyWith(status: LlamaModelStatus.waitingForWifi));
      await _persist();
      return;
    }

    final existing = await _transport.taskForId(_taskId);
    if (existing != null && _isManagerTask(existing)) {
      if (existing.status == LlamaModelDownloadStatus.running) {
        _pausedForWifi = false;
        _emit(_state.copyWith(status: LlamaModelStatus.downloading));
        await _persist();
        return;
      }
      if (existing.status == LlamaModelDownloadStatus.enqueued ||
          existing.status == LlamaModelDownloadStatus.waitingToRetry) {
        _pausedForWifi = false;
        _emit(_state.copyWith(status: LlamaModelStatus.queued));
        await _persist();
        return;
      }
      if (existing.status == LlamaModelDownloadStatus.complete) {
        await _verifyAndPromote();
        return;
      }
      if ((existing.status == LlamaModelDownloadStatus.paused ||
              existing.status == null) &&
          await _transport.resume(existing)) {
        _pausedForWifi = false;
        _emit(_state.copyWith(status: LlamaModelStatus.queued));
        await _persist();
        return;
      }
      await _transport.cancel(_taskId);
    }

    final task = await _newTask();
    try {
      if (!await _transport.enqueue(task)) {
        await _fail(LlamaModelFailure.enqueue);
        return;
      }
    } on Object {
      await _fail(LlamaModelFailure.enqueue);
      return;
    }
    _pausedForWifi = false;
    _emit(_state.copyWith(status: LlamaModelStatus.queued));
    await _persist();
  }

  Future<LlamaModelDownloadTask> _newTask() async => LlamaModelDownloadTask(
    taskId: _taskId,
    group: taskGroup,
    url: _model!.url,
    relativeDirectory: await _storage.relativeDirectory(_modelId),
    filename: 'model.gguf.part',
    metadata: {
      'modelId': _modelId,
      'catalogRevision': _model!.revision,
      'sha256': _model!.sha256,
      'expectedBytes': '${_model!.expectedBytes}',
    },
  );

  bool _isManagerTask(LlamaModelDownloadTask task) =>
      task.taskId == _taskId &&
      task.group == taskGroup &&
      task.metadata['modelId'] == _modelId &&
      task.metadata['catalogRevision'] == _model!.revision &&
      task.metadata['sha256'] == _model!.sha256 &&
      task.metadata['expectedBytes'] == '${_model!.expectedBytes}';

  void _onDownloadEvent(LlamaModelDownloadEvent event) {
    if (_disposed || _model == null || !_isManagerTask(event.task)) return;
    if (event is LlamaModelDownloadProgressEvent) {
      if (event.expectedBytes case final reported?
          when !_isExpectedSize(reported)) {
        unawaited(_singleFlight('verify', _rejectReportedSize));
        return;
      }
      final progress = event.progress.clamp(0.0, 1.0);
      if (!_pausedForWifi && !_state.userPaused) {
        _emit(
          _state.copyWith(
            status: LlamaModelStatus.downloading,
            progress: progress,
            downloadedBytes: (_model!.expectedBytes * progress).round(),
          ),
        );
        unawaited(_singleFlight('progressPersist', _persist));
      }
      return;
    }
    if (event is! LlamaModelDownloadStatusEvent) return;
    switch (event.status) {
      case LlamaModelDownloadStatus.enqueued:
        _emit(_state.copyWith(status: LlamaModelStatus.queued));
      case LlamaModelDownloadStatus.running:
        if (!_pausedForWifi && !_state.userPaused) {
          _emit(_state.copyWith(status: LlamaModelStatus.downloading));
        }
      case LlamaModelDownloadStatus.paused:
        _emit(
          _state.copyWith(
            status: _pausedForWifi
                ? LlamaModelStatus.waitingForWifi
                : LlamaModelStatus.paused,
          ),
        );
      case LlamaModelDownloadStatus.complete:
        unawaited(_singleFlight('verify', _verifyAndPromote));
      case LlamaModelDownloadStatus.failed:
        unawaited(
          _singleFlight('verify', () => _fail(LlamaModelFailure.download)),
        );
      case LlamaModelDownloadStatus.canceled:
        break;
      case LlamaModelDownloadStatus.waitingToRetry:
        _emit(_state.copyWith(status: LlamaModelStatus.queued));
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> values) {
    if (_disposed || _model == null || !_state.optedIn) return;
    final wifi = values.contains(ConnectivityResult.wifi);
    if (!wifi &&
        (_state.status == LlamaModelStatus.downloading ||
            _state.status == LlamaModelStatus.queued)) {
      _pausedForWifi = true;
      unawaited(_singleFlight('wifi', _pauseForWifi));
    } else if (wifi && _pausedForWifi && !_state.userPaused && _state.optedIn) {
      unawaited(_singleFlight('wifi', _attemptStartOrWait));
    }
  }

  Future<void> _pauseForWifi() async {
    final task = await _transport.taskForId(_taskId);
    if (task != null && _isManagerTask(task)) await _transport.pause(task);
    _emit(_state.copyWith(status: LlamaModelStatus.waitingForWifi));
    await _persist();
  }

  Future<void> _rejectReportedSize() async {
    await _transport.cancel(_taskId);
    final partial = await _storage.partialFile(_modelId);
    if (await partial.exists()) await partial.delete();
    await _fail(LlamaModelFailure.expectedSizeMismatch);
  }

  Future<void> _verifyAndPromote() async {
    _emit(_state.copyWith(status: LlamaModelStatus.verifying));
    final partial = await _storage.partialFile(_modelId);
    try {
      if (!await partial.exists() || !_isExpectedSize(await partial.length())) {
        if (await partial.exists()) await partial.delete();
        await _fail(LlamaModelFailure.expectedSizeMismatch);
        return;
      }
      final digest = await sha256.bind(partial.openRead()).first;
      final actualHash = digest.toString().toLowerCase();
      if (actualHash != _model!.sha256) {
        await partial.delete();
        await _fail(LlamaModelFailure.checksumMismatch);
        return;
      }

      await _storage.promotePartial(_modelId);
      final installed = await _storage.installedFile(_modelId);
      await _platformStorage.excludeFromBackup(installed.path);
      final installedAt = _clock().toUtc();
      await _storage.writeManifest(_modelId, {
        'schemaVersion': 1,
        'modelId': _modelId,
        'catalogRevision': _model!.revision,
        'sha256': actualHash,
        'expectedBytes': _model!.expectedBytes,
        'actualBytes': await installed.length(),
        'installedAt': installedAt.toIso8601String(),
        'license': _model!.license,
      });
      _emit(
        _state.copyWith(
          status: LlamaModelStatus.installed,
          progress: 1,
          downloadedBytes: _model!.expectedBytes,
          installedPath: installed.path,
          verifiedSha256: actualHash,
          installedAt: installedAt,
          clearFailure: true,
        ),
      );
      await _persist();
    } on Object {
      if (await partial.exists()) await partial.delete();
      await _fail(LlamaModelFailure.fileSystem);
    }
  }

  bool _isExpectedSize(int actualBytes) {
    return actualBytes == _model!.expectedBytes;
  }

  Future<bool> _hasValidInstallation() async {
    final installed = await _storage.installedFile(_modelId);
    final manifest = await _storage.readManifest(_modelId);
    if (!await installed.exists() || manifest == null) return false;
    return _isExpectedSize(await installed.length()) &&
        manifest['modelId'] == _modelId &&
        manifest['catalogRevision'] == _model!.revision &&
        manifest['sha256'] == _model!.sha256 &&
        manifest['expectedBytes'] == _model!.expectedBytes &&
        _state.verifiedSha256 == _model!.sha256;
  }

  Future<void> _removeInvalidInstallation() async {
    for (final file in [
      await _storage.installedFile(_modelId),
      await _storage.manifestFile(_modelId),
    ]) {
      if (await file.exists()) await file.delete();
    }
    if (_state.installedPath != null || _state.verifiedSha256 != null) {
      _emit(
        _state.copyWith(
          progress: 0,
          downloadedBytes: 0,
          clearInstallation: true,
        ),
      );
      await _persist();
    }
  }

  Future<void> _prepareDirectory() async {
    if (_directoryPrepared) return;
    await _storage.ensureModelDirectory(_modelId);
    final directory = await _storage.modelDirectory(_modelId);
    await _platformStorage.excludeFromBackup(directory.path);
    _directoryPrepared = true;
  }

  Future<void> _fail(
    LlamaModelFailure failure, {
    LlamaModelStatus status = LlamaModelStatus.failed,
  }) async {
    _emit(_state.copyWith(status: status, failure: failure));
    await _persist();
  }

  void _emit(LlamaModelState value) {
    if (_disposed) return;
    _state = value;
    _states.add(value);
  }

  Future<void> _persist() => _storage.writeState(
    _modelId,
    _state.copyWith(
      taskId: _model == null ? null : _taskId,
      catalogRevision: _model?.revision,
    ),
  );

  Future<void> _singleFlight(String name, Future<void> Function() operation) {
    final active = _flights[name];
    if (active != null) return active;
    final future = _operationTail.then((_) => operation());
    _operationTail = future.catchError((Object _) {});
    _flights[name] = future;
    return future.whenComplete(() {
      if (identical(_flights[name], future)) _flights.remove(name);
    });
  }

  void _checkReady() {
    if (_disposed) throw StateError('LlamaModelManager is disposed.');
    if (!_initialized) throw StateError('Call initialize() first.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _downloadSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _operationTail;
    await _transport.dispose();
    await _states.close();
  }
}
