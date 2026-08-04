import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../api/api_exceptions.dart';
import '../sync/encrypted_sync_engine.dart';
import '../sync/sync_outbox.dart';
import 'cloud_relay_api_transport.dart';

enum CloudRelayConnectionState {
  disabled,
  encryptedRelayConnected,
  syncing,
  offlineQueue,
  error,
}

@immutable
final class CloudRelayDevice {
  const CloudRelayDevice({
    required this.id,
    required this.lastActiveAt,
    required this.isCurrentDevice,
    required this.keyEpoch,
  });

  final String id;
  final DateTime lastActiveAt;
  final bool isCurrentDevice;
  final int keyEpoch;
}

typedef CloudRelayOnlineCheck = FutureOr<bool> Function();
typedef CloudRelayDelay = Future<void> Function(Duration duration);

/// Background coordinator for the encrypted CRDT engine and opaque relay.
///
/// Cryptography and deterministic vector-clock reconciliation remain in
/// [EncryptedSyncEngine]. This coordinator observes the SQLite outbox, batches
/// sync work, handles connectivity, and adds bounded exponential retry.
final class CloudRelaySyncEngine extends ChangeNotifier {
  CloudRelaySyncEngine({
    required this.syncEngine,
    required this.outbox,
    required this.transport,
    required CloudRelayOnlineCheck isOnline,
    DateTime Function()? clock,
    CloudRelayDelay? delay,
    Random? random,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 5),
    this.maxRetryAttempts = 4,
    CloudRelayConnectionState initialState = CloudRelayConnectionState.disabled,
  }) : // A public parameter cannot use a private initializing formal.
       // ignore: prefer_initializing_formals
       _isOnline = isOnline,
       _clock = clock ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random.secure(),
       _state = initialState {
    if (maxRetryAttempts < 1) throw ArgumentError.value(maxRetryAttempts);
    _outboxSubscription = outbox.changes.listen(_onOutboxChanged);
    _engineSubscription = syncEngine.states.listen(_onEngineState);
    _deviceSubscription = transport.relayDeviceChanges.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }

  final EncryptedSyncEngine syncEngine;
  final SyncOutbox outbox;
  final CloudRelayDeviceDirectory transport;
  final CloudRelayOnlineCheck _isOnline;
  final DateTime Function() _clock;
  final CloudRelayDelay _delay;
  final Random _random;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final int maxRetryAttempts;

  late final StreamSubscription<int> _outboxSubscription;
  late final StreamSubscription<EncryptedSyncState> _engineSubscription;
  late final StreamSubscription<List<CloudRelayDevicePresence>>
  _deviceSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  Future<void>? _syncFuture;
  CloudRelayConnectionState _state;
  DateTime? _lastSyncedAt;
  DateTime? _nextRetryAt;
  int _attempt = 0;
  Object? _lastError;
  bool _started = false;
  bool _disposed = false;

  CloudRelayConnectionState get state => _state;
  int get pendingCount => outbox.pendingCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get nextRetryAt => _nextRetryAt;
  int get retryAttempt => _attempt;
  Object? get lastError => _lastError;

  List<CloudRelayDevice> get devices {
    final values = <String, CloudRelayDevice>{};
    for (final device in transport.relayDevices) {
      values[device.id] = CloudRelayDevice(
        id: device.id,
        lastActiveAt: device.lastActiveAt,
        isCurrentDevice: device.id == syncEngine.deviceId,
        keyEpoch: 0,
      );
    }
    for (final device in syncEngine.devices) {
      values[device.id] = CloudRelayDevice(
        id: device.id,
        lastActiveAt: device.lastSeenAt,
        isCurrentDevice: device.isCurrentDevice,
        keyEpoch: device.keyEpoch,
      );
    }
    final sorted = values.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return List.unmodifiable(sorted);
  }

  void start({
    Stream<bool>? connectivityChanges,
    Duration interval = const Duration(minutes: 5),
  }) {
    _started = true;
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => unawaited(syncNow()));
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivityChanges?.listen((online) {
      if (online) {
        unawaited(syncNow());
      } else {
        _setState(CloudRelayConnectionState.offlineQueue);
      }
    });
    if (pendingCount > 0) _scheduleOutboxSync();
  }

  Future<void> syncNow() {
    if (_disposed) return Future.value();
    final active = _syncFuture;
    if (active != null) return active;
    final future = _runSyncWithRetry();
    _syncFuture = future;
    return future.whenComplete(() {
      if (identical(_syncFuture, future)) _syncFuture = null;
    });
  }

  Future<void> _runSyncWithRetry() async {
    _debounceTimer?.cancel();
    if (!await _isOnline()) {
      _setState(CloudRelayConnectionState.offlineQueue);
      return;
    }
    Object? terminalError;
    for (var attempt = 1; attempt <= maxRetryAttempts; attempt++) {
      if (_disposed) return;
      _attempt = attempt;
      _nextRetryAt = null;
      _lastError = null;
      _setState(CloudRelayConnectionState.syncing);
      try {
        await syncEngine.syncNow();
        _attempt = 0;
        _lastSyncedAt = _clock().toUtc();
        _setState(CloudRelayConnectionState.encryptedRelayConnected);
        return;
      } on Object catch (error) {
        terminalError = error;
        _lastError = error;
        if (!await _isOnline()) {
          _setState(CloudRelayConnectionState.offlineQueue);
          return;
        }
        if (!_isRetryable(error) || attempt == maxRetryAttempts) break;
        final wait = _backoff(attempt);
        _nextRetryAt = _clock().toUtc().add(wait);
        notifyListeners();
        await _delay(wait);
      }
    }
    _lastError = terminalError;
    _setState(CloudRelayConnectionState.error);
  }

  Future<String> revokeDevice(String deviceId) async {
    if (deviceId == syncEngine.deviceId) {
      throw ArgumentError('The current device cannot revoke itself.');
    }
    await transport.revokeRelayDevice(deviceId);
    final phrase = await syncEngine.revokeDevice(deviceId);
    await syncNow();
    notifyListeners();
    return phrase;
  }

  void _onOutboxChanged(int count) {
    if (_disposed) return;
    notifyListeners();
    if (_started && count > 0) _scheduleOutboxSync();
  }

  void _scheduleOutboxSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(syncNow()),
    );
  }

  void _onEngineState(EncryptedSyncState state) {
    if (_disposed) return;
    switch (state) {
      case EncryptedSyncState.disabled:
        _setState(CloudRelayConnectionState.disabled);
      case EncryptedSyncState.offline:
        _setState(CloudRelayConnectionState.offlineQueue);
      case EncryptedSyncState.syncing:
        _setState(CloudRelayConnectionState.syncing);
      case EncryptedSyncState.upToDate:
        _setState(CloudRelayConnectionState.encryptedRelayConnected);
      case EncryptedSyncState.error:
        // Retry ownership belongs to this coordinator.
        break;
    }
  }

  bool _isRetryable(Object error) =>
      (error is CloudRelayTransportException && error.retryable) ||
      error is ConnectivityException ||
      error is NetworkOfflineException ||
      error is RequestTimeoutException ||
      error is ServiceUnavailableException ||
      error is RateLimitedException ||
      error is TimeoutException;

  Duration _backoff(int attempt) {
    final exponent = min(attempt - 1, 30);
    final jitter = .75 + _random.nextDouble() * .5;
    final milliseconds = baseBackoff.inMilliseconds * (1 << exponent) * jitter;
    return Duration(
      milliseconds: min(milliseconds.round(), maxBackoff.inMilliseconds),
    );
  }

  void _setState(CloudRelayConnectionState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_outboxSubscription.cancel());
    unawaited(_engineSubscription.cancel());
    unawaited(_deviceSubscription.cancel());
    super.dispose();
  }
}
