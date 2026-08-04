import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/llm/background_downloader_llama_transport.dart';
import '../core/llm/llama_model_catalog.dart';
import '../core/llm/llama_model_manager.dart';
import '../core/llm/llama_model_state.dart';
import '../core/llm/llama_model_storage.dart';
import '../core/llm/native/llama_inference_session.dart';
import '../security/app_lock_service.dart';

/// Process-scoped ownership and lifecycle coordination for the local model.
///
/// This adapter deliberately keeps platform plugin construction out of trial
/// and test service graphs; [AppServices] creates it only for a live app.
final class LlamaServiceLifecycle {
  LlamaServiceLifecycle({
    LlamaModelManager? manager,
    LlamaInferenceSession? session,
    Future<bool> Function()? foregroundUnlocked,
  }) : _foregroundUnlocked = foregroundUnlocked ?? _defaultForegroundUnlocked,
       manager =
           manager ??
           LlamaModelManager(
             catalog: LlamaModelCatalog.fromBuildEnvironment(),
             transport: BackgroundDownloaderLlamaTransport(),
             platformStorage: NativeLlamaModelPlatformStorage(),
             storage: LlamaModelStorage(),
             foregroundUnlocked:
                 foregroundUnlocked ?? _defaultForegroundUnlocked,
           ),
       _session = session ?? LlamaInferenceSession();

  final LlamaModelManager manager;
  final Future<bool> Function() _foregroundUnlocked;
  final StreamController<int> _graphRevisions = StreamController<int>.broadcast(
    sync: true,
  );

  LlamaInferenceSession _session;
  StreamSubscription<LlamaModelState>? _modelStates;
  Future<void>? _initialization;
  Future<void> _sessionTail = Future<void>.value();
  LlamaModelStatus? _lastStatus;
  int _graphRevision = 0;
  bool _disposed = false;

  LlamaInferenceSession get session => _session;
  Stream<int> get graphRevisions => _graphRevisions.stream;

  /// Initializes and reconciles downloader state exactly once.
  Future<void> initialize() {
    final existing = _initialization;
    if (existing != null) return existing;
    _modelStates = manager.states.listen(_handleModelState);
    final initialization = manager.initialize().then((_) {
      _handleModelState(manager.state);
    });
    _initialization = initialization;
    return initialization;
  }

  Future<LlamaInferenceSession?> readySession() async {
    if (_disposed || !await _foregroundUnlocked()) return null;
    await initialize();
    if (manager.state.status != LlamaModelStatus.installed) return null;
    await _warmInstalledModel();
    return _session.isReady ? _session : null;
  }

  /// Called only after both foreground and app-lock checks have succeeded.
  Future<void> onForegroundUnlocked() async {
    if (_disposed || !await _foregroundUnlocked()) return;
    await initialize();
    if (manager.state.status == LlamaModelStatus.installed) {
      await _warmInstalledModel();
    }
  }

  Future<void> removeForPrivacyWipe() async {
    if (_disposed) return;
    await initialize();
    await manager.optOut();
    await _sessionTail;
  }

  void _handleModelState(LlamaModelState state) {
    if (_disposed) return;
    final previous = _lastStatus;
    _lastStatus = state.status;
    if (previous == LlamaModelStatus.installed &&
        state.status != LlamaModelStatus.installed) {
      _emitGraphRevision();
      unawaited(_resetSession());
      return;
    }
    if (state.status == LlamaModelStatus.installed) {
      unawaited(_warmIfAllowed());
    }
  }

  Future<void> _warmIfAllowed() async {
    if (await _foregroundUnlocked()) await _warmInstalledModel();
  }

  Future<void> _warmInstalledModel() {
    final operation = _sessionTail.then((_) async {
      if (_disposed || _session.isReady) return;
      final path = manager.state.installedPath;
      if (manager.state.status != LlamaModelStatus.installed ||
          path == null ||
          path.isEmpty ||
          !await _foregroundUnlocked()) {
        return;
      }
      await _session.warmUp(modelPath: path);
      _emitGraphRevision();
    });
    _sessionTail = operation.catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('Local model warm-up failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
    return _sessionTail;
  }

  Future<void> _resetSession() {
    final operation = _sessionTail.then((_) async {
      if (_disposed) return;
      final previous = _session;
      _session = LlamaInferenceSession();
      await previous.dispose();
    });
    _sessionTail = operation.catchError((Object _) {});
    return operation;
  }

  void _emitGraphRevision() {
    if (!_disposed) _graphRevisions.add(++_graphRevision);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _modelStates?.cancel();
    await _sessionTail;
    await _session.dispose();
    await manager.dispose();
    await _graphRevisions.close();
  }

  static Future<bool> _defaultForegroundUnlocked() async =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      !await AppLockService.instance.isLocked();
}
