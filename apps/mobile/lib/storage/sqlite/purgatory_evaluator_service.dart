import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/crsql_delta_ingestor.dart';
import 'package:sqflite/sqflite.dart';

/// Flushes `sync_purgatory` on a background isolate once parent rows exist.
class PurgatoryEvaluatorService {
  PurgatoryEvaluatorService({
    this.interval = defaultInterval,
    Future<int> Function()? evaluateOverride,
  }) : _evaluateOverride = evaluateOverride;

  /// Process-wide evaluator used by sync completion and app lifecycle.
  static final PurgatoryEvaluatorService instance = PurgatoryEvaluatorService();

  static const Duration defaultInterval = Duration(seconds: 30);

  final Duration interval;
  final Future<int> Function()? _evaluateOverride;

  String? filePath;
  String? encryptionPassword;
  String? keyAlias;

  Timer? _timer;
  var _sessionActive = false;

  bool get sessionActive => _sessionActive;

  /// Points batch completion at [instance.afterP2pBatch].
  static void installBatchHook() {
    CrsqlDeltaIngestor.onBatchEvaluated = instance.afterP2pBatch;
  }

  void configure({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
  }) {
    this.filePath = filePath;
    this.encryptionPassword = encryptionPassword;
    this.keyAlias = keyAlias;
  }

  /// Starts the active-session timer and flushes parked rows after a batch.
  void afterP2pBatch(String path) {
    if (_isMemory(path)) return;
    filePath = path;
    if (_skipSingletonBackground) return;
    beginSyncSession();
    _scheduleEvaluate();
  }

  void beginSyncSession() {
    _sessionActive = true;
    _timer ??= Timer.periodic(interval, (_) {
      if (!_sessionActive) return;
      _scheduleEvaluate();
    });
  }

  void endSyncSession() {
    _sessionActive = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Flushes parked rows when the process starts.
  Future<int> onStartup() => _lifecycleEvaluate();

  /// Flushes parked rows when the app returns to the foreground.
  Future<int> onForeground() => _lifecycleEvaluate();

  Future<int> _lifecycleEvaluate() {
    if (_skipSingletonBackground) return Future<int>.value(0);
    return evaluate();
  }

  /// Runs one purgatory pass on the persistent background database isolate.
  Future<int> evaluate() {
    final override = _evaluateOverride;
    if (override != null) return override();
    final path = filePath;
    if (path == null || _isMemory(path)) return Future<int>.value(0);
    return LocalDatabaseWorkerService.instance.runPurgatoryEvaluate(
      filePath: path,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
    );
  }

  void _scheduleEvaluate() {
    unawaited(
      evaluate().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Background purgatory flush failed: $error',
            name: 'PurgatoryEvaluator',
            level: 900,
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  bool get _skipSingletonBackground =>
      identical(this, instance) &&
      Platform.environment.containsKey('FLUTTER_TEST');

  static bool _isMemory(String path) =>
      path.isEmpty || path == ':memory:' || path == inMemoryDatabasePath;
}
