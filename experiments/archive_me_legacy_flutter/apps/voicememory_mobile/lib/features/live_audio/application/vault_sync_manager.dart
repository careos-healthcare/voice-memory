import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/retry_policy.dart';
import '../domain/vault_chunk_payload.dart';
import '../infrastructure/emergency_vault_storage.dart';
import '../infrastructure/live_audio_pipeline_log.dart';
import '../infrastructure/vault_upload_api_client.dart';

typedef VaultRetryDelay = Future<void> Function(Duration duration);
typedef VaultIntegrityRecoveryBackstop = Future<void> Function();

enum SyncState { idle, syncing, offline, error }

class VaultSyncManager {
  VaultSyncManager({
    required this.vaultStorage,
    required this.apiClient,
    this.retryPolicy = const RetryPolicy(),
    Connectivity? connectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    VaultRetryDelay? retryDelay,
    this.integrityRecoveryBackstop,
    this.enableConnectivityListener = true,
  }) : connectivity = connectivity ?? Connectivity(),
       // Public named parameters cannot use private field names.
       // ignore: prefer_initializing_formals
       _connectivityChanges = connectivityChanges,
       _retryDelay = retryDelay ?? Future<void>.delayed {
    if (enableConnectivityListener) {
      _initConnectivityListener();
    }
  }

  final EmergencyVaultStorage vaultStorage;
  final VaultUploadApiClient apiClient;
  final RetryPolicy retryPolicy;
  final Connectivity connectivity;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
  final VaultRetryDelay _retryDelay;
  final VaultIntegrityRecoveryBackstop? integrityRecoveryBackstop;
  final bool enableConnectivityListener;

  final _syncStateController = StreamController<SyncState>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncState _currentState = SyncState.idle;
  bool _isProcessing = false;
  Future<void>? _processingFuture;

  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  SyncState get currentState => _currentState;

  void _initConnectivityListener() {
    _connectivitySubscription =
        (_connectivityChanges ?? connectivity.onConnectivityChanged).listen((
          results,
        ) {
          final isConnected = results.any((r) => r != ConnectivityResult.none);
          if (isConnected &&
              (_currentState == SyncState.offline ||
                  _currentState == SyncState.error)) {
            unawaited(processPendingVaultQueue());
          } else if (!isConnected) {
            _updateState(SyncState.offline);
          }
        });
  }

  Future<void> processPendingVaultQueue() {
    final active = _processingFuture;
    if (active != null) return active;
    final future = _processPendingVaultQueue();
    _processingFuture = future;
    return future.whenComplete(() {
      if (identical(_processingFuture, future)) _processingFuture = null;
    });
  }

  Future<void> _processPendingVaultQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _updateState(SyncState.syncing);

    try {
      while (true) {
        final pendingChunks = await vaultStorage.getUnsyncedChunks();
        if (pendingChunks.isEmpty) {
          _updateState(SyncState.idle);
          return;
        }

        for (final chunk in pendingChunks) {
          final explicitlyAcknowledged = await _uploadChunkWithRetry(chunk);
          if (!explicitlyAcknowledged) {
            _updateState(SyncState.error);
            return;
          }
          await vaultStorage.markChunkSynced(chunk.id);
        }

        // Reads and mutations are serialized by storage, so this cannot remove
        // a chunk appended while the network upload was in flight.
        await vaultStorage.purgeSyncedChunks();
      }
    } on EmergencyVaultIntegrityException catch (error) {
      LiveAudioPipelineLog.failure('vault_chunk_integrity', error);
      _updateState(SyncState.error);
      final backstop = integrityRecoveryBackstop;
      if (backstop != null) {
        try {
          await backstop();
        } on Object catch (backstopError) {
          LiveAudioPipelineLog.failure(
            'vault_chunk_integrity_backstop',
            backstopError,
          );
        }
      }
    } catch (error) {
      LiveAudioPipelineLog.failure('vault_chunk_sync', error);
      _updateState(SyncState.error);
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _uploadChunkWithRetry(VaultChunkPayload chunk) async {
    var attempts = 0;

    while (retryPolicy.shouldRetry(attempts)) {
      attempts++;
      try {
        final uploaded = await apiClient.uploadVaultChunk(chunk);

        if (uploaded) return true;
      } catch (error) {
        LiveAudioPipelineLog.failure('vault_chunk_upload', error);
      }

      if (retryPolicy.shouldRetry(attempts)) {
        final delay = retryPolicy.calculateDelay(attempts);
        await _retryDelay(delay);
      }
    }

    return false;
  }

  void _updateState(SyncState state) {
    _currentState = state;
    if (!_syncStateController.isClosed) {
      _syncStateController.add(state);
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _processingFuture;
    await _syncStateController.close();
  }
}
