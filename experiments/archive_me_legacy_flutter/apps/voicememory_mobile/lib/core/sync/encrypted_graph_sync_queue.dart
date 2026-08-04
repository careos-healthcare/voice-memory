import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'encrypted_graph_sync_engine.dart';
import 'google_drive_graph_sync_transport.dart';
import 'icloud_drive_graph_sync_transport.dart';
import 'platform_encrypted_graph_sync_transport.dart';

typedef GraphSyncQueueClock = DateTime Function();
typedef GraphSyncQueueDelay = Future<void> Function(Duration duration);
typedef GraphSyncQueueOnlineCheck = Future<bool> Function();
typedef GraphSyncQueueIdFactory = String Function();

enum EncryptedGraphSyncQueueFailure {
  offline,
  retryable,
  authorizationRequired,
  notConfigured,
  nonRetryable,
}

/// A durable upload record. The envelope is encrypted graph data; the whole
/// manifest is additionally authenticated and encrypted at rest.
final class EncryptedGraphSyncQueueItem {
  const EncryptedGraphSyncQueueItem({
    required this.id,
    required this.target,
    required this.path,
    required this.encryptedEnvelope,
    required this.enqueuedAt,
    required this.attemptCount,
    required this.lastFailure,
    required this.nextAttemptAt,
  });

  final String id;
  final EncryptedGraphSyncTarget target;
  final String path;
  final String encryptedEnvelope;
  final DateTime enqueuedAt;
  final int attemptCount;
  final EncryptedGraphSyncQueueFailure? lastFailure;
  final DateTime? nextAttemptAt;

  EncryptedGraphSyncQueueItem copyWith({
    String? encryptedEnvelope,
    DateTime? enqueuedAt,
    int? attemptCount,
    EncryptedGraphSyncQueueFailure? lastFailure,
    bool clearFailure = false,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
  }) => EncryptedGraphSyncQueueItem(
    id: id,
    target: target,
    path: path,
    encryptedEnvelope: encryptedEnvelope ?? this.encryptedEnvelope,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastFailure: clearFailure ? null : (lastFailure ?? this.lastFailure),
    nextAttemptAt: clearNextAttemptAt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'target': target.name,
    'path': path,
    'encryptedEnvelope': encryptedEnvelope,
    'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
    'attemptCount': attemptCount,
    'lastFailure': lastFailure?.name,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
  };

  factory EncryptedGraphSyncQueueItem.fromJson(Map<String, dynamic> json) {
    const fields = <String>{
      'id',
      'target',
      'path',
      'encryptedEnvelope',
      'enqueuedAt',
      'attemptCount',
      'lastFailure',
      'nextAttemptAt',
    };
    final actualFields = json.keys.toSet();
    if (actualFields.length != fields.length ||
        !actualFields.containsAll(fields)) {
      throw const FormatException('Invalid graph sync queue item fields.');
    }
    final id = json['id'];
    final targetName = json['target'];
    final path = json['path'];
    final envelope = json['encryptedEnvelope'];
    final enqueuedAtValue = json['enqueuedAt'];
    final attemptCount = json['attemptCount'];
    final failureName = json['lastFailure'];
    final nextAttemptAtValue = json['nextAttemptAt'];
    if (id is! String ||
        id.isEmpty ||
        targetName is! String ||
        path is! String ||
        envelope is! String ||
        envelope.isEmpty ||
        enqueuedAtValue is! String ||
        attemptCount is! int ||
        attemptCount < 0 ||
        (failureName != null && failureName is! String) ||
        (nextAttemptAtValue != null && nextAttemptAtValue is! String)) {
      throw const FormatException('Invalid graph sync queue item types.');
    }
    final target = EncryptedGraphSyncTarget.values
        .where((value) => value.name == targetName)
        .firstOrNull;
    final failure = failureName == null
        ? null
        : EncryptedGraphSyncQueueFailure.values
              .where((value) => value.name == failureName)
              .firstOrNull;
    final enqueuedAt = DateTime.tryParse(enqueuedAtValue);
    final nextAttemptAt = nextAttemptAtValue == null
        ? null
        : DateTime.tryParse(nextAttemptAtValue);
    if (target == null ||
        (failureName != null && failure == null) ||
        enqueuedAt == null ||
        (nextAttemptAtValue != null && nextAttemptAt == null)) {
      throw const FormatException('Invalid graph sync queue item values.');
    }
    _validateSafePath(path);
    EncryptedGraphSyncEnvelope.decode(envelope);
    return EncryptedGraphSyncQueueItem(
      id: id,
      target: target,
      path: path,
      encryptedEnvelope: envelope,
      enqueuedAt: enqueuedAt.toUtc(),
      attemptCount: attemptCount,
      lastFailure: failure,
      nextAttemptAt: nextAttemptAt?.toUtc(),
    );
  }
}

class EncryptedGraphSyncQueueManifestException implements Exception {
  const EncryptedGraphSyncQueueManifestException();

  @override
  String toString() =>
      'EncryptedGraphSyncQueueManifestException: queue manifest is invalid.';
}

class EncryptedGraphSyncQueuedFailureException implements Exception {
  const EncryptedGraphSyncQueuedFailureException(this.failure);

  final EncryptedGraphSyncQueueFailure failure;

  @override
  String toString() =>
      'EncryptedGraphSyncQueuedFailureException: ${failure.name}.';
}

/// A decorating transport that durably queues encrypted uploads.
///
/// Calling [drain] at startup/resume is explicit. Connectivity changes trigger
/// the same foreground/unlocked-gated drain; this class does not schedule work
/// after the app process has been killed.
class EncryptedGraphSyncQueue implements EncryptedGraphSyncTransport {
  EncryptedGraphSyncQueue({
    required File manifestFile,
    required PrivateDataEncryptionKeyStore keyStore,
    required EncryptedGraphSyncTransport transport,
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required Future<bool> Function() foregroundUnlocked,
    GraphSyncQueueOnlineCheck? isOnline,
    GraphSyncQueueClock? clock,
    GraphSyncQueueDelay? delay,
    GraphSyncQueueIdFactory? idFactory,
    Random? random,
    this.maxRetryAttemptsPerDrain = 3,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 5),
  }) : _store = EncryptedJsonFileStore(file: manifestFile, keyStore: keyStore),
       // A public named parameter cannot be an initializing formal for a
       // private field.
       // ignore: prefer_initializing_formals
       _transport = transport,
       // ignore: prefer_initializing_formals
       _foregroundUnlocked = foregroundUnlocked,
       _isOnline =
           isOnline ??
           (() async {
             final values = await Connectivity().checkConnectivity();
             return values.any((value) => value != ConnectivityResult.none);
           }),
       _clock = clock ?? DateTime.now,
       _injectedDelay = delay,
       // ignore: prefer_initializing_formals
       _idFactory = idFactory,
       _random = random ?? Random.secure() {
    if (maxRetryAttemptsPerDrain < 1) {
      throw ArgumentError.value(maxRetryAttemptsPerDrain);
    }
    _connectivitySubscription = connectivityChanges.listen(
      _onConnectivityChanged,
    );
  }

  static const manifestVersion = 1;

  final EncryptedJsonFileStore _store;
  final EncryptedGraphSyncTransport _transport;
  final Future<bool> Function() _foregroundUnlocked;
  final GraphSyncQueueOnlineCheck _isOnline;
  final GraphSyncQueueClock _clock;
  final GraphSyncQueueDelay? _injectedDelay;
  final GraphSyncQueueIdFactory? _idFactory;
  final Random _random;
  final int maxRetryAttemptsPerDrain;
  final Duration baseBackoff;
  final Duration maxBackoff;

  late final StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;
  final Set<Timer> _timers = <Timer>{};
  final Set<Completer<void>> _timerCompleters = <Completer<void>>{};
  List<EncryptedGraphSyncQueueItem>? _items;
  Future<void> _stateTail = Future<void>.value();
  Future<void>? _drainFuture;
  bool? _connectivityAvailable;
  bool _disposed = false;

  Future<List<EncryptedGraphSyncQueueItem>> get items async =>
      List<EncryptedGraphSyncQueueItem>.unmodifiable(
        await _withStateLock(() async {
          await _ensureLoaded();
          return List<EncryptedGraphSyncQueueItem>.from(_items!);
        }),
      );

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) => _transport.download(target: target, path: path);

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    _checkNotDisposed();
    _validateSafePath(path);
    EncryptedGraphSyncEnvelope.decode(encryptedEnvelope);
    final now = _clock().toUtc();
    late String itemId;
    await _withStateLock(() async {
      await _ensureLoaded();
      final existingIndex = _items!.indexWhere(
        (item) => item.target == target && item.path == path,
      );
      if (existingIndex < 0) {
        itemId = _newId();
        _items!.add(
          EncryptedGraphSyncQueueItem(
            id: itemId,
            target: target,
            path: path,
            encryptedEnvelope: encryptedEnvelope,
            enqueuedAt: now,
            attemptCount: 0,
            lastFailure: null,
            nextAttemptAt: null,
          ),
        );
      } else {
        final existing = _items![existingIndex];
        itemId = existing.id;
        _items![existingIndex] = existing.copyWith(
          encryptedEnvelope: encryptedEnvelope,
          enqueuedAt: now,
          attemptCount: 0,
          clearFailure: true,
          clearNextAttemptAt: true,
        );
      }
      await _persist();
    });
    await drain();
    final retained = (await items)
        .where((item) => item.id == itemId)
        .firstOrNull;
    if (retained?.lastFailure == EncryptedGraphSyncQueueFailure.nonRetryable) {
      throw const EncryptedGraphSyncQueuedFailureException(
        EncryptedGraphSyncQueueFailure.nonRetryable,
      );
    }
  }

  /// Drains due items once. Concurrent callers share one single-flight future.
  Future<void> drain() {
    if (_disposed) return Future<void>.value();
    final active = _drainFuture;
    if (active != null) return active;
    final future = _runDrain();
    _drainFuture = future;
    return future.whenComplete(() {
      if (identical(_drainFuture, future)) _drainFuture = null;
    });
  }

  Future<void> _runDrain() async {
    if (_disposed || !await _foregroundUnlocked()) return;
    if (!await _onlineNow()) {
      await _markAllOffline();
      return;
    }
    final snapshot = await items;
    for (final item in snapshot) {
      if (_disposed) return;
      var current = await _itemWithId(item.id);
      if (current == null) continue;
      final nextAttemptAt = current.nextAttemptAt;
      if (nextAttemptAt != null && nextAttemptAt.isAfter(_clock().toUtc())) {
        continue;
      }
      var retriesThisDrain = 0;
      while (current != null && !_disposed) {
        if (!await _canAttempt()) return;
        try {
          await _transport.upload(
            target: current.target,
            path: current.path,
            encryptedEnvelope: current.encryptedEnvelope,
          );
          await _removeIfCurrent(current);
          break;
        } on Object catch (error) {
          final failure = classifyEncryptedGraphSyncQueueFailure(error);
          final attemptCount = current.attemptCount + 1;
          if (failure != EncryptedGraphSyncQueueFailure.retryable) {
            await _recordFailure(
              current,
              failure: failure,
              attemptCount: attemptCount,
              nextAttemptAt: null,
            );
            break;
          }
          retriesThisDrain++;
          final backoff = _backoff(attemptCount);
          await _recordFailure(
            current,
            failure: failure,
            attemptCount: attemptCount,
            nextAttemptAt: _clock().toUtc().add(backoff),
          );
          if (retriesThisDrain >= maxRetryAttemptsPerDrain) break;
          await _wait(backoff);
          current = await _itemWithId(current.id);
        }
      }
    }
  }

  Future<bool> _canAttempt() async {
    if (_disposed || !await _foregroundUnlocked()) return false;
    return !_disposed && await _onlineNow();
  }

  Future<bool> _onlineNow() async {
    if (_connectivityAvailable == false) return false;
    return _isOnline();
  }

  Future<void> _markAllOffline() => _withStateLock(() async {
    await _ensureLoaded();
    var changed = false;
    for (var index = 0; index < _items!.length; index++) {
      final item = _items![index];
      if (item.lastFailure == EncryptedGraphSyncQueueFailure.offline &&
          item.nextAttemptAt == null) {
        continue;
      }
      _items![index] = item.copyWith(
        lastFailure: EncryptedGraphSyncQueueFailure.offline,
        clearNextAttemptAt: true,
      );
      changed = true;
    }
    if (changed) await _persist();
  });

  void _onConnectivityChanged(List<ConnectivityResult> values) {
    if (_disposed) return;
    final available = values.any((value) => value != ConnectivityResult.none);
    final wasAvailable = _connectivityAvailable;
    _connectivityAvailable = available;
    if (available && wasAvailable == false) {
      unawaited(_drainAfterConnectivity());
    }
  }

  Future<void> _drainAfterConnectivity() async {
    try {
      await drain();
    } on Object {
      // Automatic triggers cannot report errors to a caller. Items and typed
      // failure classifications remain available through [items].
    }
  }

  Duration _backoff(int attemptCount) {
    final exponent = min(attemptCount - 1, 30);
    final rawMilliseconds =
        baseBackoff.inMilliseconds *
        (1 << exponent) *
        (0.75 + _random.nextDouble() * 0.5);
    return Duration(
      milliseconds: min(rawMilliseconds.round(), maxBackoff.inMilliseconds),
    );
  }

  Future<void> _wait(Duration duration) {
    final injected = _injectedDelay;
    if (injected != null) return injected(duration);
    if (_disposed) return Future<void>.value();
    final completer = Completer<void>();
    _timerCompleters.add(completer);
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      _timerCompleters.remove(completer);
      if (!completer.isCompleted) completer.complete();
    });
    _timers.add(timer);
    return completer.future;
  }

  Future<EncryptedGraphSyncQueueItem?> _itemWithId(String id) =>
      _withStateLock(() async {
        await _ensureLoaded();
        return _items!.where((item) => item.id == id).firstOrNull;
      });

  Future<void> _removeIfCurrent(EncryptedGraphSyncQueueItem attempted) =>
      _withStateLock(() async {
        await _ensureLoaded();
        _items!.removeWhere(
          (item) =>
              item.id == attempted.id &&
              item.encryptedEnvelope == attempted.encryptedEnvelope,
        );
        await _persist();
      });

  Future<void> _recordFailure(
    EncryptedGraphSyncQueueItem attempted, {
    required EncryptedGraphSyncQueueFailure failure,
    required int attemptCount,
    required DateTime? nextAttemptAt,
  }) => _withStateLock(() async {
    await _ensureLoaded();
    final index = _items!.indexWhere(
      (item) =>
          item.id == attempted.id &&
          item.encryptedEnvelope == attempted.encryptedEnvelope,
    );
    if (index < 0) return;
    _items![index] = _items![index].copyWith(
      attemptCount: attemptCount,
      lastFailure: failure,
      nextAttemptAt: nextAttemptAt,
      clearNextAttemptAt: nextAttemptAt == null,
    );
    await _persist();
  });

  Future<void> _ensureLoaded() async {
    if (_items != null) return;
    try {
      final value = await _store.readJson();
      if (value == null) {
        _items = <EncryptedGraphSyncQueueItem>[];
        return;
      }
      if (value is! Map) throw const FormatException();
      final manifest = Map<String, dynamic>.from(value);
      final manifestFields = manifest.keys.toSet();
      if (manifestFields.length != 2 ||
          !manifestFields.containsAll(const <String>{'version', 'items'}) ||
          manifest['version'] != manifestVersion ||
          manifest['items'] is! List) {
        throw const FormatException();
      }
      final loaded = (manifest['items'] as List)
          .map((value) {
            if (value is! Map) throw const FormatException();
            return EncryptedGraphSyncQueueItem.fromJson(
              Map<String, dynamic>.from(value),
            );
          })
          .toList(growable: true);
      final keys = <String>{};
      final ids = <String>{};
      for (final item in loaded) {
        if (!ids.add(item.id) ||
            !keys.add('${item.target.name}\u0000${item.path}')) {
          throw const FormatException();
        }
      }
      _items = loaded;
    } on Object {
      throw const EncryptedGraphSyncQueueManifestException();
    }
  }

  Future<void> _persist() => _store.writeJson(<String, Object>{
    'version': manifestVersion,
    'items': _items!.map((item) => item.toJson()).toList(growable: false),
  });

  Future<T> _withStateLock<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _stateTail = _stateTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _newId() {
    final factory = _idFactory;
    if (factory != null) {
      final id = factory();
      if (id.isEmpty) {
        throw StateError('Queue id factory returned an empty id.');
      }
      return id;
    }
    return List<String>.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Encrypted graph sync queue is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectivitySubscription.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final completer in _timerCompleters) {
      if (!completer.isCompleted) completer.complete();
    }
    _timerCompleters.clear();
    await _drainFuture;
  }
}

EncryptedGraphSyncQueueFailure classifyEncryptedGraphSyncQueueFailure(
  Object error,
) {
  if (error is GoogleDriveGraphSyncException) {
    return switch (error.code) {
      GoogleDriveGraphSyncErrorCode.notConfigured =>
        EncryptedGraphSyncQueueFailure.notConfigured,
      GoogleDriveGraphSyncErrorCode.authorizationRequired =>
        EncryptedGraphSyncQueueFailure.authorizationRequired,
      GoogleDriveGraphSyncErrorCode.retryable =>
        EncryptedGraphSyncQueueFailure.retryable,
      _ => EncryptedGraphSyncQueueFailure.nonRetryable,
    };
  }
  if (error is ICloudDriveGraphSyncUnavailableException) {
    return EncryptedGraphSyncQueueFailure.authorizationRequired;
  }
  if (error is ICloudDriveGraphSyncBridgeException) {
    return EncryptedGraphSyncQueueFailure.notConfigured;
  }
  if (error is ICloudDriveGraphSyncTimeoutException ||
      error is ICloudDriveGraphSyncOperationException ||
      error is TimeoutException ||
      error is SocketException ||
      error is IOException) {
    return EncryptedGraphSyncQueueFailure.retryable;
  }
  if (error is PlatformEncryptedGraphSyncTransportException) {
    return error.code == PlatformEncryptedGraphSyncErrorCode.notConfigured
        ? EncryptedGraphSyncQueueFailure.notConfigured
        : EncryptedGraphSyncQueueFailure.nonRetryable;
  }
  if (error is MissingPluginException) {
    return EncryptedGraphSyncQueueFailure.notConfigured;
  }
  if (error is PlatformException) {
    return switch (error.code) {
      'not_configured' ||
      'missing_plugin' => EncryptedGraphSyncQueueFailure.notConfigured,
      'authorization_required' ||
      'unauthorized' ||
      'unavailable' => EncryptedGraphSyncQueueFailure.authorizationRequired,
      'timeout' ||
      'operation_timeout' ||
      'network' ||
      'io_error' => EncryptedGraphSyncQueueFailure.retryable,
      _ => EncryptedGraphSyncQueueFailure.nonRetryable,
    };
  }
  return EncryptedGraphSyncQueueFailure.nonRetryable;
}

void _validateSafePath(String path) {
  final segments = path.split('/');
  if (path.isEmpty ||
      path.length > 512 ||
      path.startsWith('/') ||
      path.contains('\\') ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw const FormatException('Graph sync queue path is not safe.');
  }
}
