import 'dart:async';

import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/settings/views/sync_status_view.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// Live sync line for settings: "Syncing...", "Synced 2 min ago", or a failure.
class SyncStatusNotifier extends ChangeNotifier {
  SyncStatusMessage _value = const SyncStatusMessage.idle();

  SyncStatusMessage get value => _value;

  void syncing() => _set(const SyncStatusMessage.syncing());

  void synced(DateTime at) => _set(SyncStatusMessage.synced(at.toUtc()));

  void failed(String reason) => _set(SyncStatusMessage.failed(reason));

  void restore(SyncStatusMessage previous) => _set(previous);

  void _set(SyncStatusMessage next) {
    _value = next;
    notifyListeners();
  }
}

class SyncStatusMessage {
  const SyncStatusMessage._(this.phase, this.syncedAt, this.reason);

  const SyncStatusMessage.idle() : this._(SyncPhase.idle, null, null);

  const SyncStatusMessage.syncing() : this._(SyncPhase.syncing, null, null);

  const SyncStatusMessage.synced(DateTime at) : this._(SyncPhase.synced, at, null);

  const SyncStatusMessage.failed(String reason)
    : this._(SyncPhase.failed, null, reason);

  final SyncPhase phase;
  final DateTime? syncedAt;
  final String? reason;

  String label(DateTime now) {
    switch (phase) {
      case SyncPhase.idle:
        return 'Not synced yet';
      case SyncPhase.syncing:
        return 'Syncing...';
      case SyncPhase.failed:
        return 'Sync failed: ${reason ?? 'unknown'}';
      case SyncPhase.synced:
        final at = syncedAt;
        if (at == null) return 'Not synced yet';
        final minutes = now.difference(at).inMinutes;
        if (minutes < 1) return 'Synced just now';
        if (minutes < 60) return 'Synced $minutes min ago';
        final hours = minutes ~/ 60;
        return hours == 1 ? 'Synced 1 hr ago' : 'Synced $hours hr ago';
    }
  }
}

enum SyncPhase { idle, syncing, synced, failed }

/// The status line settings and the scheduler share.
final syncStatusNotifier = SyncStatusNotifier();

/// Debounces local journal writes and pulls on a foreground timer.
class SyncScheduler {
  SyncScheduler({
    Future<bool> Function()? push,
    Future<bool> Function()? pull,
    this.pushDebounce = const Duration(seconds: 2),
    this.foregroundInterval = const Duration(minutes: 15),
    SyncStatusNotifier? status,
  }) : _push = push ?? _runEncryptedSync,
       _pull = pull ?? _runEncryptedSync,
       status = status ?? syncStatusNotifier;

  static final instance = SyncScheduler();

  final Future<bool> Function() _push;
  final Future<bool> Function() _pull;
  final Duration pushDebounce;
  final Duration foregroundInterval;
  final SyncStatusNotifier status;

  Timer? _debounce;
  Timer? _foreground;

  /// Create, update, and soft-delete all wait [pushDebounce] before one push.
  void noteLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(pushDebounce, () {
      unawaited(_run(_push));
    });
  }

  /// Pulls deltas and tombstones while the app stays in the foreground.
  void startForeground() {
    if (_foreground != null) return;
    _foreground = Timer.periodic(foregroundInterval, (_) {
      unawaited(_run(_pull));
    });
  }

  void pauseForeground() {
    _foreground?.cancel();
    _foreground = null;
  }

  void stop() {
    _debounce?.cancel();
    _foreground?.cancel();
    _debounce = null;
    _foreground = null;
  }

  Future<void> _run(Future<bool> Function() job) async {
    final previous = status.value;
    status.syncing();
    try {
      final completed = await job();
      if (!completed) {
        if (status.value.phase == SyncPhase.syncing) status.restore(previous);
        return;
      }
      if (status.value.phase == SyncPhase.syncing) {
        status.synced(DateTime.now().toUtc());
      }
    } on Object catch (error) {
      final reason = error is SyncSchedulerException
          ? error.reason
          : 'the archive did not accept this sync';
      status.failed(reason);
    }
  }

  static Future<bool> _runEncryptedSync() async {
    final report = await E2eeSyncLifecycle.syncIfEnabled();
    switch (report.outcome) {
      case E2eeSyncOutcome.skipped:
        return false;
      case E2eeSyncOutcome.synced:
        try {
          await SyncDeviceDirectory.registerCurrent();
        } on Object {
          // The device list can catch up on the next successful sync.
        }
        return true;
      case E2eeSyncOutcome.failed:
        throw SyncSchedulerException(
          report.reason ?? 'the archive did not accept this sync',
        );
    }
  }
}

class SyncSchedulerException implements Exception {
  const SyncSchedulerException(this.reason);

  final String reason;
}

/// Asks for a debounced push after a journal row is saved.
class JournalSyncScheduleInterceptor implements JournalSaveInterceptor {
  const JournalSyncScheduleInterceptor();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    SyncScheduler.instance.noteLocalChange();
  }
}
