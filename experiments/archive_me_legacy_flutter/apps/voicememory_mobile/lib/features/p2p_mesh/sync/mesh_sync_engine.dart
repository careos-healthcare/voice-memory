import 'dart:async';
import 'dart:math';

import 'mesh_sync_checkpoint.dart';
import 'mesh_sync_reconciler.dart';
import 'peer_sync_channel.dart';

enum MeshEngineState { idle, reconciling, upToDate, disconnected, error }

class MeshSyncProgress {
  const MeshSyncProgress({
    required this.peerId,
    required this.state,
    this.sentChunks = 0,
    this.receivedChunks = 0,
    this.appliedWinners = 0,
    this.error,
  });

  final String peerId;
  final MeshEngineState state;
  final int sentChunks;
  final int receivedChunks;
  final int appliedWinners;
  final Object? error;
}

/// Symmetric differential reconciliation over an authenticated mesh session.
class MeshSyncEngine {
  MeshSyncEngine({
    required this.reconciler,
    required this.checkpoints,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now;

  final MeshSyncReconciler reconciler;
  final EncryptedMeshCheckpointStore checkpoints;
  final Random _random;
  final DateTime Function() _clock;
  final _progress = StreamController<MeshSyncProgress>.broadcast();
  final Set<String> _activePeers = {};
  bool _paused = false;

  Stream<MeshSyncProgress> get progress => _progress.stream;
  bool get isPaused => _paused;

  Future<void> quiesce() async {
    _paused = true;
    while (_activePeers.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void resume() => _paused = false;

  Future<void> synchronize(
    AuthenticatedPeerSyncChannel channel, {
    required bool initiator,
    Map<String, dynamic>? initialRequest,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_paused) throw StateError('Mesh synchronization is paused.');
    if (!_activePeers.add(channel.peerId)) {
      throw StateError('A mesh sync is already active for this peer.');
    }
    var sent = 0;
    var received = 0;
    var applied = 0;
    final iterator = StreamIterator(channel.packets);
    _emit(channel.peerId, MeshEngineState.reconciling);
    var reconciliationLocked = false;
    try {
      await reconciler.engine.beginPeerReconciliation();
      reconciliationLocked = true;
      late final String exchangeId;
      late final Map<String, dynamic> peerSummary;
      final existing = await checkpoints.load(channel.peerId);
      if (initiator) {
        exchangeId =
            existing?.exchangeId ??
            '${reconciler.engine.deviceId}-${_clock().toUtc().microsecondsSinceEpoch}-'
                '${_random.nextInt(1 << 32)}';
        await channel.send({
          'version': 1,
          'type': 'sync_start',
          'exchangeId': exchangeId,
          'sourceDeviceId': reconciler.engine.deviceId,
          'summary': await reconciler.createHeadSummary(),
        });
        final response = await _next(iterator, timeout);
        _validateControl(
          response,
          type: 'sync_summary',
          peerId: channel.peerId,
          exchangeId: exchangeId,
        );
        peerSummary = _requiredMap(response, 'summary');
      } else {
        final request = initialRequest ?? await _next(iterator, timeout);
        _validateControl(request, type: 'sync_start', peerId: channel.peerId);
        exchangeId = '${request['exchangeId']}';
        peerSummary = _requiredMap(request, 'summary');
        await channel.send({
          'version': 1,
          'type': 'sync_summary',
          'exchangeId': exchangeId,
          'sourceDeviceId': reconciler.engine.deviceId,
          'summary': await reconciler.createHeadSummary(),
        });
      }

      var sequence = _resumeSequence(existing, exchangeId);
      var outbound = await reconciler.exportNextChunk(
        peerId: channel.peerId,
        exchangeId: exchangeId,
        sequence: sequence,
        peerSummary: peerSummary,
      );
      await channel.send(outbound);
      sent++;
      var localComplete = false;
      var remoteComplete = false;

      while (!localComplete || !remoteComplete) {
        final packet = await _next(iterator, timeout);
        if (packet['type'] == 'crdt_chunk') {
          final result = await reconciler.applyAuthenticatedChunk(
            authenticatedPeerId: channel.peerId,
            chunk: packet,
          );
          await channel.send(result.acknowledgement);
          received++;
          applied += result.appliedWinnerCount;
          remoteComplete = packet['isLast'] == true;
        } else if (packet['type'] == 'crdt_ack') {
          await reconciler.applyAcknowledgement(
            authenticatedPeerId: channel.peerId,
            acknowledgement: packet,
          );
          if ('${packet['chunkId']}' == '${outbound['chunkId']}') {
            if (outbound['isLast'] == true) {
              localComplete = true;
            } else {
              sequence++;
              outbound = await reconciler.exportNextChunk(
                peerId: channel.peerId,
                exchangeId: exchangeId,
                sequence: sequence,
                peerSummary: peerSummary,
              );
              await channel.send(outbound);
              sent++;
            }
          }
        } else {
          throw FormatException(
            'Unexpected mesh sync packet: ${packet['type']}',
          );
        }
        _progress.add(
          MeshSyncProgress(
            peerId: channel.peerId,
            state: MeshEngineState.reconciling,
            sentChunks: sent,
            receivedChunks: received,
            appliedWinners: applied,
          ),
        );
      }
      await checkpoints.remove(channel.peerId);
      _progress.add(
        MeshSyncProgress(
          peerId: channel.peerId,
          state: MeshEngineState.upToDate,
          sentChunks: sent,
          receivedChunks: received,
          appliedWinners: applied,
        ),
      );
    } on TimeoutException catch (error) {
      _progress.add(
        MeshSyncProgress(
          peerId: channel.peerId,
          state: MeshEngineState.disconnected,
          sentChunks: sent,
          receivedChunks: received,
          appliedWinners: applied,
          error: error,
        ),
      );
      rethrow;
    } on Object catch (error) {
      _progress.add(
        MeshSyncProgress(
          peerId: channel.peerId,
          state: MeshEngineState.error,
          sentChunks: sent,
          receivedChunks: received,
          appliedWinners: applied,
          error: error,
        ),
      );
      rethrow;
    } finally {
      await iterator.cancel();
      if (reconciliationLocked) {
        reconciler.engine.endPeerReconciliation();
      }
      _activePeers.remove(channel.peerId);
    }
  }

  int _resumeSequence(MeshSyncCheckpoint? checkpoint, String exchangeId) {
    if (checkpoint == null || checkpoint.exchangeId != exchangeId) return 0;
    if (checkpoint.outboundChunks.isNotEmpty) {
      final packet = checkpoint.outboundChunks.values.first;
      return (packet['sequence'] as num?)?.toInt() ?? 0;
    }
    return checkpoint.acknowledgedChunkIds.length;
  }

  Future<Map<String, dynamic>> _next(
    StreamIterator<Map<String, dynamic>> iterator,
    Duration timeout,
  ) async {
    if (!await iterator.moveNext().timeout(timeout)) {
      throw const FormatException('Mesh peer closed the sync stream.');
    }
    return iterator.current;
  }

  void _validateControl(
    Map<String, dynamic> packet, {
    required String type,
    required String peerId,
    String? exchangeId,
  }) {
    if (packet['version'] != 1 ||
        packet['type'] != type ||
        '${packet['sourceDeviceId']}' != peerId ||
        (exchangeId != null && '${packet['exchangeId']}' != exchangeId)) {
      throw FormatException('Invalid $type mesh control packet.');
    }
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> packet, String key) {
    final value = packet[key];
    if (value is! Map) throw FormatException('Missing mesh $key.');
    return Map<String, dynamic>.from(value);
  }

  void _emit(String peerId, MeshEngineState state) {
    _progress.add(MeshSyncProgress(peerId: peerId, state: state));
  }

  Future<void> dispose() async {
    await quiesce();
    await _progress.close();
  }
}
