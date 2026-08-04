import 'dart:async';
import 'dart:math';

import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../config/archive_me_demo_state.dart';
import '../config/creator_demo_mode.dart';
import '../core/sync/journal_sync_conflict_resolver.dart';
import '../features/journal/sync/saved_moment_sync.dart';
import '../features/archive_ownership/local_archive_identity.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import 'capture_save_messages.dart';
import 'sync_diagnostic_log.dart';

class SyncResult {
  const SyncResult({
    required this.cloudSyncSucceeded,
    required this.message,
    this.syncNote,
    required this.pushed,
    required this.pulled,
    this.conflictsResolved = 0,
    this.failureCode,
  });

  final bool cloudSyncSucceeded;
  final String message;
  final String? syncNote;
  final int pushed;
  final int pulled;
  final int conflictsResolved;
  final SyncFailureCode? failureCode;

  /// Legacy alias — cloud sync only.
  bool get ok => cloudSyncSucceeded;
}

enum SyncFailureCode { ownerScopeMismatch }

typedef SyncRetryDelay = Future<void> Function(Duration duration);
typedef SyncClock = DateTime Function();
typedef SyncRandomDouble = double Function();
typedef SyncDeviceIdProvider = Future<String> Function();
typedef SyncArchiveIdentityProvider = LocalArchiveIdentity Function();
typedef SyncJournalProvider = JournalStore Function();
typedef SyncKeyProvider = Future<List<int>> Function(String ownerArchiveId);

/// Bounded retry seam for foreground journal synchronization.
///
/// The default preserves the previous one-attempt behavior. Tests and callers
/// that want foreground retries can inject deterministic delay and jitter.
class SyncRetryCoordinator {
  const SyncRetryCoordinator({
    this.maxAttempts = 1,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.delay,
    this.randomDouble,
  }) : assert(maxAttempts > 0);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final SyncRetryDelay? delay;
  final SyncRandomDouble? randomDouble;

  Future<T> run<T>(
    Future<T> Function() operation, {
    required bool Function(Object error) isRetryable,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await operation();
      } on Object catch (error) {
        if (attempt >= maxAttempts || !isRetryable(error)) rethrow;
        final exponent = min(attempt - 1, 20);
        final ceiling = min(
          baseDelay.inMilliseconds * (1 << exponent),
          maxDelay.inMilliseconds,
        );
        final jitter = (randomDouble ?? Random().nextDouble)();
        if (jitter < 0 || jitter >= 1) {
          throw StateError('Sync retry jitter must be in the range [0, 1).');
        }
        final duration = Duration(milliseconds: (ceiling * jitter).round());
        await (delay ?? Future<void>.delayed)(duration);
      }
    }
  }
}

class SyncService {
  SyncService(
    this._api,
    this._journal,
    this._prefs, {
    this.retryCoordinator = const SyncRetryCoordinator(),
    SyncClock? clock,
    SyncDeviceIdProvider? deviceIdProvider,
    SyncArchiveIdentityProvider? archiveIdentityProvider,
    SyncJournalProvider? journalProvider,
    this._keyProvider,
  }) : _clock = clock ?? DateTime.now,
       _archiveIdentityProvider = archiveIdentityProvider,
       _journalProvider = journalProvider,
       _deviceIdProvider =
           deviceIdProvider ?? SyncService._defaultDeviceIdProvider;

  final JournalSyncApiClient _api;
  final JournalStore _journal;
  final SyncJournalProvider? _journalProvider;
  final MobilePrefsStore _prefs;
  final SyncRetryCoordinator retryCoordinator;
  final SyncClock _clock;
  final SyncDeviceIdProvider _deviceIdProvider;
  final SyncArchiveIdentityProvider? _archiveIdentityProvider;
  final SyncKeyProvider? _keyProvider;
  final SavedMomentSyncCipher _cipher = const SavedMomentSyncCipher();
  Future<SyncResult>? _syncFuture;
  bool _paused = false;
  int _scopeGeneration = 0;

  JournalStore get _activeJournal => _journalProvider?.call() ?? _journal;

  void pauseForAccountTransition() {
    _paused = true;
    _scopeGeneration += 1;
  }

  void resumeAfterAccountTransition() {
    _paused = false;
  }

  Future<SyncResult> syncNow() {
    final active = _syncFuture;
    if (active != null) return active;
    final future = _syncNow();
    _syncFuture = future;
    return future.whenComplete(() {
      if (identical(_syncFuture, future)) _syncFuture = null;
    });
  }

  Future<SyncResult> _syncNow() async {
    if (_paused) return _scopeMismatch();
    final generation = _scopeGeneration;
    // Creator demo mode: nothing syncs — no backend call is ever made and
    // no demo content can reach an account.
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        pushed: 0,
        pulled: 0,
      );
    }
    if (!AppConfig.isBackendConfigured) {
      return const SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: 0,
        pulled: 0,
      );
    }
    var pushed = 0;
    var pulled = 0;
    var conflictsResolved = 0;
    String? deviceId;
    List<int>? keyBytes;
    try {
      final identity = _archiveIdentityProvider?.call();
      final ownerArchiveId = identity?.archiveId.trim();
      if (identity == null ||
          !identity.maySync ||
          ownerArchiveId == null ||
          ownerArchiveId.isEmpty ||
          _keyProvider == null) {
        return const SyncResult(
          cloudSyncSucceeded: false,
          message: 'Sign in to use encrypted archive sync.',
          pushed: 0,
          pulled: 0,
        );
      }
      deviceId = await _deviceIdProvider();
      keyBytes = await _keyProvider(ownerArchiveId);
      if (!_scopeIsCurrent(identity, generation)) return _scopeMismatch();
      // Pull before push so a stale local edit cannot blindly overwrite a
      // newer revision already accepted from another device.
      final pull = await retryCoordinator.run(
        _api.syncPull,
        isRetryable: _isRetryable,
      );
      final remote = <JournalEntry>[];
      for (final blob in pull.blobs.where(
        (item) => item['type'] == 'journal_snapshot',
      )) {
        final envelope = EncryptedSavedMomentEnvelope.fromSyncBlob(
          blob,
          ownerArchiveId: ownerArchiveId,
        );
        final record = await _cipher.decrypt(
          envelope,
          expectedOwnerArchiveId: ownerArchiveId,
          keyBytes: keyBytes,
        );
        remote.add(
          JournalEntry.fromJson(
            record.payload,
          ).copyWith(ownerArchiveId: ownerArchiveId),
        );
      }
      pulled = remote.length;
      final merge = await _activeJournal.mergeRemote(
        remote,
        localDeviceId: deviceId,
      );
      conflictsResolved = merge.collisions.length;

      final pending = await _activeJournal.pendingSyncQueue();
      final blobs = <Map<String, dynamic>>[];
      for (final entry in pending) {
        if (!_scopeIsCurrent(identity, generation) ||
            entry.ownerArchiveId != ownerArchiveId) {
          return _scopeMismatch();
        }
        final revision = entry.updatedAt.microsecondsSinceEpoch;
        final record = SavedMomentSyncRecord.fromMoment(
          entry,
          ownerArchiveId: ownerArchiveId,
          revision: revision,
          sourceDeviceId: deviceId,
        );
        final envelope = await _cipher.encrypt(record, keyBytes: keyBytes);
        blobs.add(envelope.toSyncBlob(updatedAt: entry.updatedAt));
      }
      if (blobs.isNotEmpty) {
        if (!_scopeIsCurrent(identity, generation)) return _scopeMismatch();
        // The declared binding lets the server reject a batch that was
        // prepared under a previous account before it writes anything.
        await retryCoordinator.run(
          () => _api.syncPush({
            'blobs': blobs,
            'expectedAccountId': identity.authenticatedSubjectId,
            'expectedArchiveId': ownerArchiveId,
          }),
          isRetryable: _isRetryable,
        );
      }
      for (final entry in pending) {
        if (!_scopeIsCurrent(identity, generation)) return _scopeMismatch();
        await _activeJournal.markSynced(entry.id);
        pushed++;
      }

      await _persistManifest(deviceId);
      await _prefs.setLastSyncAt(_clock());
      return SyncResult(
        cloudSyncSucceeded: true,
        message: conflictsResolved == 0
            ? 'Sync complete. If anything looks duplicated, newer copies were kept.'
            : 'Sync complete. $conflictsResolved conflicting ${conflictsResolved == 1 ? 'edit was' : 'edits were'} resolved using the newest revision.',
        pushed: pushed,
        pulled: pulled,
        conflictsResolved: conflictsResolved,
      );
    } on Object catch (error, stackTrace) {
      if (deviceId != null) {
        try {
          await _persistManifest(deviceId);
        } on Object {
          // The primary sync error remains authoritative.
        }
      }
      return _failureResult(error, stackTrace, pushed: pushed, pulled: pulled);
    } finally {
      keyBytes?.fillRange(0, keyBytes.length, 0);
    }
  }

  Future<void> _persistManifest(String deviceId) async {
    final previous = await _prefs.journalSyncManifest;
    final manifest = JournalSyncManifest.fromEntries(
      entries: await _activeJournal.loadAll(includeDeleted: true),
      deviceId: deviceId,
      generatedAt: _clock(),
      version: (previous?.version ?? 0) + 1,
    );
    await _prefs.setJournalSyncManifest(manifest);
  }

  bool _scopeIsCurrent(LocalArchiveIdentity expected, int generation) {
    final current = _archiveIdentityProvider?.call();
    return !_paused &&
        generation == _scopeGeneration &&
        current?.archiveId == expected.archiveId &&
        current?.authenticatedSubjectId == expected.authenticatedSubjectId &&
        current?.maySync == true;
  }

  static SyncResult _scopeMismatch() => const SyncResult(
    cloudSyncSucceeded: false,
    message: 'Archive ownership changed. Sync was safely paused.',
    pushed: 0,
    pulled: 0,
    failureCode: SyncFailureCode.ownerScopeMismatch,
  );

  static Future<String> _defaultDeviceIdProvider() async => 'local-device';

  static bool _isRetryable(Object error) {
    if (error is NetworkOfflineException ||
        error is ConnectivityException ||
        error is RequestTimeoutException ||
        error is TimeoutException) {
      return true;
    }
    if (error is ApiException) {
      final status = error.statusCode ?? 0;
      return status == 408 || status == 429 || status >= 500;
    }
    return false;
  }

  static SyncResult _failureResult(
    Object error,
    StackTrace stackTrace, {
    required int pushed,
    required int pulled,
  }) {
    if (error is AuthRequiredException) {
      _logFailure('authentication', error, stackTrace);
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sign in to sync your archive to the server.',
        pushed: pushed,
        pulled: pulled,
      );
    }
    if (error is BackendNotConfiguredException) {
      _logFailure('permanent_configuration', error, stackTrace);
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: pushed,
        pulled: pulled,
      );
    }
    final failureType = switch (error) {
      NetworkOfflineException() => 'transient_network',
      ApiException() => _apiFailureType(error),
      _ => 'unexpected',
    };
    _logFailure(failureType, error, stackTrace);
    return SyncResult(
      cloudSyncSucceeded: false,
      message: 'Sync did not complete.',
      syncNote: CaptureSaveMessages.syncNoteFor(error),
      pushed: pushed,
      pulled: pulled,
    );
  }

  static String _apiFailureType(ApiException error) {
    if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
      return 'authentication';
    }
    final status = error.statusCode ?? 0;
    if (status == 408 || status == 429 || status >= 500) {
      return 'transient_api';
    }
    return 'permanent_api';
  }

  static void _logFailure(
    String failureType,
    Object error,
    StackTrace stackTrace,
  ) {
    SyncDiagnosticLog.failed(
      operation: 'sync_now',
      failureType: failureType,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String> lastSyncLabel() async {
    if (!AppConfig.isBackendConfigured) {
      return ConsumerUiCopy.syncNotAvailableTestFlight;
    }
    final raw = await _prefs.lastSyncAt;
    if (raw == null) return ConsumerUiCopy.syncOnDeviceOnly;
    final at = DateTime.tryParse(raw);
    if (at == null) return ConsumerUiCopy.syncOnDeviceOnly;
    return 'Last sync ${at.toLocal()}';
  }
}
