import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum FFIResourceKind {
  llamaSession,
  llamaOutput,
  loraJob,
  sqliteDatabase,
  whisperOperation,
  nativeAudioRecorder,
  hivemindSession,
  spatialSession,
  sandboxSession,
}

enum FFISafetyEventType {
  acquired,
  released,
  duplicateRelease,
  useAfterRelease,
  finalizedWithoutRelease,
}

final class FFISafetyEvent {
  const FFISafetyEvent({
    required this.resourceId,
    required this.kind,
    required this.owner,
    required this.type,
    required this.occurredAt,
  });

  final int resourceId;
  final FFIResourceKind kind;
  final String owner;
  final FFISafetyEventType type;
  final DateTime occurredAt;
}

final class FFIResourceRecord {
  const FFIResourceRecord({
    required this.id,
    required this.kind,
    required this.owner,
    required this.createdAt,
    required this.estimatedBytes,
    required this.released,
    this.releasedAt,
    this.finalizedWithoutRelease = false,
  });

  final int id;
  final FFIResourceKind kind;
  final String owner;
  final DateTime createdAt;
  final int estimatedBytes;
  final bool released;
  final DateTime? releasedAt;
  final bool finalizedWithoutRelease;

  FFIResourceRecord copyWith({
    bool? released,
    DateTime? releasedAt,
    bool? finalizedWithoutRelease,
  }) => FFIResourceRecord(
    id: id,
    kind: kind,
    owner: owner,
    createdAt: createdAt,
    estimatedBytes: estimatedBytes,
    released: released ?? this.released,
    releasedAt: releasedAt ?? this.releasedAt,
    finalizedWithoutRelease:
        finalizedWithoutRelease ?? this.finalizedWithoutRelease,
  );
}

final class FFISafetySnapshot {
  const FFISafetySnapshot({
    required this.activeCount,
    required this.activeEstimatedBytes,
    required this.processRssBytes,
    required this.finalizerLeakCount,
    required this.duplicateReleaseCount,
    required this.byKind,
    required this.byOwner,
    required this.pressureHigh,
  });

  final int activeCount;
  final int activeEstimatedBytes;
  final int processRssBytes;
  final int finalizerLeakCount;
  final int duplicateReleaseCount;
  final Map<FFIResourceKind, int> byKind;
  final Map<String, int> byOwner;
  final bool pressureHigh;
}

typedef FFIPressureHook = FutureOr<void> Function();

final class FFISafetyMonitor {
  FFISafetyMonitor({
    this.rssPressureThresholdBytes = 768 * 1024 * 1024,
    this.resourcePressureThreshold = 64,
    this.maximumEventHistory = 256,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static FFISafetyMonitor? _installed;
  static FFISafetyMonitor? get installed => _installed;
  static void install(FFISafetyMonitor? monitor) => _installed = monitor;

  final int rssPressureThresholdBytes;
  final int resourcePressureThreshold;
  final int maximumEventHistory;
  final DateTime Function() _clock;
  final Map<int, FFIResourceRecord> _records = {};
  final Queue<FFISafetyEvent> _events = Queue<FFISafetyEvent>();
  final Map<String, FFIPressureHook> _pressureHooks = {};
  final StreamController<FFISafetySnapshot> _snapshots =
      StreamController<FFISafetySnapshot>.broadcast();
  static final Finalizer<({FFISafetyMonitor monitor, int id})> _finalizer =
      Finalizer<({FFISafetyMonitor monitor, int id})>((token) {
        token.monitor._markFinalized(token.id);
      });
  int _nextId = 0;
  int _duplicateReleaseCount = 0;
  int _finalizerLeakCount = 0;
  bool _pressureRunning = false;

  Stream<FFISafetySnapshot> get snapshots => _snapshots.stream;
  FFISafetySnapshot get snapshot => _buildSnapshot();

  FFIResourceLease acquire(
    FFIResourceKind kind, {
    required String owner,
    int estimatedBytes = 0,
  }) {
    final id = ++_nextId;
    _records[id] = FFIResourceRecord(
      id: id,
      kind: kind,
      owner: owner,
      createdAt: _clock().toUtc(),
      estimatedBytes: estimatedBytes.clamp(0, 1 << 40).toInt(),
      released: false,
    );
    final lease = FFIResourceLease._(this, id);
    _finalizer.attach(lease, (monitor: this, id: id), detach: lease);
    _recordEvent(_records[id]!, FFISafetyEventType.acquired);
    _emit();
    unawaited(checkPressure());
    return lease;
  }

  void registerPressureHook(String id, FFIPressureHook hook) {
    _pressureHooks[id] = hook;
  }

  void unregisterPressureHook(String id) => _pressureHooks.remove(id);

  Future<bool> checkPressure() async {
    final current = snapshot;
    if (!current.pressureHigh) return false;
    if (_pressureRunning) return true;
    _pressureRunning = true;
    try {
      for (final hook in List<FFIPressureHook>.from(_pressureHooks.values)) {
        try {
          await hook();
        } on Object {
          // Pressure disposal is best-effort; one subsystem must not prevent
          // the remaining app-owned resources from receiving the signal.
        }
      }
      return true;
    } finally {
      _pressureRunning = false;
      _emit();
    }
  }

  List<FFIResourceRecord> activeResources() =>
      UnmodifiableListView(_records.values.where((record) => !record.released));

  List<FFISafetyEvent> get events => UnmodifiableListView(_events);

  void assertNoLeaks({Set<FFIResourceKind>? kinds}) {
    final leaked = _records.values.where(
      (record) =>
          !record.released && (kinds == null || kinds.contains(record.kind)),
    );
    if (leaked.isNotEmpty) {
      final summary = leaked
          .map((record) => '${record.kind.name}:${record.owner}')
          .join(', ');
      throw StateError('Unreleased app-owned native resources: $summary');
    }
  }

  void _release(int id, Object detachToken) {
    final record = _records[id];
    if (record == null || record.released) {
      _duplicateReleaseCount++;
      if (record != null) {
        _recordEvent(record, FFISafetyEventType.duplicateRelease);
      }
      _emit();
      throw StateError('Native resource $id was already released.');
    }
    _finalizer.detach(detachToken);
    _records[id] = record.copyWith(
      released: true,
      releasedAt: _clock().toUtc(),
    );
    _recordEvent(record, FFISafetyEventType.released);
    _emit();
  }

  void _ensureActive(int id) {
    final record = _records[id];
    if (record == null || record.released) {
      if (record != null) {
        _recordEvent(record, FFISafetyEventType.useAfterRelease);
      }
      _emit();
      throw StateError('Native resource $id is no longer active.');
    }
  }

  void _markFinalized(int id) {
    final record = _records[id];
    if (record == null || record.released) return;
    _finalizerLeakCount++;
    _records[id] = record.copyWith(finalizedWithoutRelease: true);
    _recordEvent(record, FFISafetyEventType.finalizedWithoutRelease);
    _emit();
  }

  @visibleForTesting
  void simulateFinalizerForTesting(FFIResourceLease lease) {
    _markFinalized(lease.id);
  }

  void _recordEvent(FFIResourceRecord record, FFISafetyEventType type) {
    if (maximumEventHistory <= 0) return;
    _events.addLast(
      FFISafetyEvent(
        resourceId: record.id,
        kind: record.kind,
        owner: record.owner,
        type: type,
        occurredAt: _clock().toUtc(),
      ),
    );
    while (_events.length > maximumEventHistory) {
      _events.removeFirst();
    }
  }

  FFISafetySnapshot _buildSnapshot() {
    final active = _records.values.where((record) => !record.released).toList();
    final byKind = <FFIResourceKind, int>{};
    final byOwner = <String, int>{};
    var bytes = 0;
    for (final record in active) {
      byKind[record.kind] = (byKind[record.kind] ?? 0) + 1;
      byOwner[record.owner] = (byOwner[record.owner] ?? 0) + 1;
      bytes += record.estimatedBytes;
    }
    final rss = ProcessInfo.currentRss;
    return FFISafetySnapshot(
      activeCount: active.length,
      activeEstimatedBytes: bytes,
      processRssBytes: rss,
      finalizerLeakCount: _finalizerLeakCount,
      duplicateReleaseCount: _duplicateReleaseCount,
      byKind: Map.unmodifiable(byKind),
      byOwner: Map.unmodifiable(byOwner),
      pressureHigh:
          active.length >= resourcePressureThreshold ||
          rss >= rssPressureThresholdBytes,
    );
  }

  void _emit() {
    if (!_snapshots.isClosed) _snapshots.add(_buildSnapshot());
  }

  Future<void> dispose() async {
    _pressureHooks.clear();
    await _snapshots.close();
  }
}

final class FFIResourceLease {
  FFIResourceLease._(this._monitor, this.id);

  final FFISafetyMonitor _monitor;
  final int id;
  bool _released = false;

  bool get isReleased => _released;

  void release() {
    if (_released) {
      _monitor._duplicateReleaseCount++;
      final record = _monitor._records[id];
      if (record != null) {
        _monitor._recordEvent(record, FFISafetyEventType.duplicateRelease);
      }
      _monitor._emit();
      throw StateError('Native resource $id was already released.');
    }
    _released = true;
    _monitor._release(id, this);
  }

  void ensureActive() => _monitor._ensureActive(id);
}
