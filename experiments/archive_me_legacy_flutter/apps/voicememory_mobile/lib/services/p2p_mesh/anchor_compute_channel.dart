import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../features/hivemind/hivemind_mesh_router.dart';
import '../../features/p2p_mesh/sync/peer_sync_channel.dart';
import '../security/mesh_identity_service.dart';

enum AnchorComputeJobKind { batchEmbeddings, llamaCouncil, museSweep }

final class AnchorComputeRequest {
  const AnchorComputeRequest({
    required this.id,
    required this.peerId,
    required this.kind,
    required this.payload,
    required this.receivedAt,
  });

  final String id;
  final String peerId;
  final AnchorComputeJobKind kind;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;
}

final class AnchorComputeMetrics {
  const AnchorComputeMetrics({
    required this.bytesSent,
    required this.bytesReceived,
    required this.lastLatency,
    required this.throughputBytesPerSecond,
  });

  final int bytesSent;
  final int bytesReceived;
  final Duration lastLatency;
  final double throughputBytesPerSecond;
}

typedef SovereignPeerConnectionFactory =
    Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);
typedef AnchorComputeRequestHandler =
    Future<Map<String, dynamic>> Function(AnchorComputeRequest request);

final class AnchorComputeChannel {
  AnchorComputeChannel({
    required this.peerId,
    required this.signaling,
    required this.initiator,
    SovereignPeerConnectionFactory? peerConnectionFactory,
    DateTime Function()? clock,
  }) : _peerConnectionFactory =
           peerConnectionFactory ??
           ((configuration) => createPeerConnection(configuration)),
       _clock = clock ?? DateTime.now;

  static const dataChannelLabel = 'archiveme-anchor-compute-v1';
  static const maxMessageBytes = 1024 * 1024;

  final String peerId;
  final AuthenticatedPeerSyncChannel signaling;
  final bool initiator;
  final SovereignPeerConnectionFactory _peerConnectionFactory;
  final DateTime Function() _clock;
  final StreamController<AnchorComputeRequest> _requests =
      StreamController<AnchorComputeRequest>.broadcast();
  final StreamController<AnchorComputeMetrics> _metrics =
      StreamController<AnchorComputeMetrics>.broadcast();
  final StreamController<bool> _connectivity =
      StreamController<bool>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, DateTime> _startedJobs = {};
  final List<RTCIceCandidate> _pendingCandidates = [];
  final List<Map<String, dynamic>> _queuedSignals = [];
  final Completer<void> _ready = Completer<void>();
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;
  RTCPeerConnection? _connection;
  RTCDataChannel? _dataChannel;
  Future<void> _signalTail = Future.value();
  int _nonce = 0;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  Duration _lastLatency = Duration.zero;
  late final DateTime _openedAt = _clock();

  Stream<AnchorComputeRequest> get requests => _requests.stream;
  Stream<AnchorComputeMetrics> get metrics => _metrics.stream;
  Stream<bool> get connectivity => _connectivity.stream;
  bool get isOpen =>
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    if (_connection != null) return _ready.future.timeout(timeout);
    _signalSubscription = signaling.packets.listen((packet) {
      if ('${packet['type']}'.startsWith('webrtc_')) {
        if (_connection == null) {
          _queuedSignals.add(Map<String, dynamic>.from(packet));
        } else {
          _signalTail = _signalTail.then((_) => _handleSignal(packet));
        }
      }
    });
    final connection = await _peerConnectionFactory({
      // No STUN/TURN servers: ICE candidates remain on the local network.
      'iceServers': const <Object>[],
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
    });
    _connection = connection;
    for (final packet in _queuedSignals) {
      _signalTail = _signalTail.then((_) => _handleSignal(packet));
    }
    _queuedSignals.clear();
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      unawaited(
        signaling.send({
          'version': 1,
          'type': 'webrtc_ice',
          'candidate': candidate.toMap(),
        }),
      );
    };
    connection.onDataChannel = _attachDataChannel;
    if (initiator) {
      final init = RTCDataChannelInit()
        ..ordered = true
        ..protocol = 'archiveme-noise-verified';
      _attachDataChannel(
        await connection.createDataChannel(dataChannelLabel, init),
      );
      final offer = await connection.createOffer();
      await connection.setLocalDescription(offer);
      await signaling.send({
        'version': 1,
        'type': 'webrtc_offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    }
    await _ready.future.timeout(timeout);
  }

  Future<Map<String, dynamic>> delegate({
    required AnchorComputeJobKind kind,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await connect(timeout: timeout);
    final id = '$peerId:${++_nonce}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _startedJobs[id] = _clock();
    try {
      await _sendData({
        'version': 1,
        'type': 'compute_request',
        'id': id,
        'kind': kind.name,
        'payload': payload,
      });
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
      _startedJobs.remove(id);
    }
  }

  Future<void> respond(
    String requestId,
    Map<String, dynamic> result, {
    String? error,
  }) => _sendData({
    'version': 1,
    'type': 'compute_result',
    'id': requestId,
    'result': result,
    'error': ?error,
  });

  Future<void> _handleSignal(Map<String, dynamic> packet) async {
    if (packet['version'] != 1) return;
    final connection = _connection;
    if (connection == null) return;
    switch (packet['type']) {
      case 'webrtc_offer':
        if (initiator) return;
        await connection.setRemoteDescription(
          RTCSessionDescription(
            packet['sdp'] as String?,
            packet['sdpType'] as String?,
          ),
        );
        await _flushCandidates(connection);
        final answer = await connection.createAnswer();
        await connection.setLocalDescription(answer);
        await signaling.send({
          'version': 1,
          'type': 'webrtc_answer',
          'sdp': answer.sdp,
          'sdpType': answer.type,
        });
      case 'webrtc_answer':
        if (!initiator) return;
        await connection.setRemoteDescription(
          RTCSessionDescription(
            packet['sdp'] as String?,
            packet['sdpType'] as String?,
          ),
        );
        await _flushCandidates(connection);
      case 'webrtc_ice':
        final raw = packet['candidate'];
        if (raw is! Map) return;
        final candidate = RTCIceCandidate(
          raw['candidate'] as String?,
          raw['sdpMid'] as String?,
          (raw['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (await connection.getRemoteDescription() == null) {
          _pendingCandidates.add(candidate);
        } else {
          await connection.addCandidate(candidate);
        }
    }
  }

  Future<void> _flushCandidates(RTCPeerConnection connection) async {
    for (final candidate in _pendingCandidates) {
      await connection.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  void _attachDataChannel(RTCDataChannel channel) {
    if (channel.label != dataChannelLabel) {
      unawaited(channel.close());
      return;
    }
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !_ready.isCompleted) {
        _ready.complete();
        _connectivity.add(true);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _connectivity.add(false);
        _failPending(StateError('Anchor compute channel closed.'));
      }
    };
    channel.onMessage = _handleDataMessage;
  }

  void _handleDataMessage(RTCDataChannelMessage message) {
    if (message.isBinary) return;
    _bytesReceived += utf8.encode(message.text).length;
    final decoded = jsonDecode(message.text);
    if (decoded is! Map || decoded['version'] != 1) return;
    final packet = Map<String, dynamic>.from(decoded);
    switch (packet['type']) {
      case 'compute_request':
        final id = packet['id'];
        final payload = packet['payload'];
        final kind = AnchorComputeJobKind.values
            .where((value) => value.name == packet['kind'])
            .firstOrNull;
        if (id is String && payload is Map && kind != null) {
          _requests.add(
            AnchorComputeRequest(
              id: id,
              peerId: peerId,
              kind: kind,
              payload: Map<String, dynamic>.from(payload),
              receivedAt: _clock().toUtc(),
            ),
          );
        }
      case 'compute_result':
        final id = packet['id'];
        final result = packet['result'];
        final pending = id is String ? _pending[id] : null;
        if (pending != null && !pending.isCompleted) {
          final started = _startedJobs[id];
          if (started != null) _lastLatency = _clock().difference(started);
          if (packet['error'] is String) {
            pending.completeError(StateError(packet['error'] as String));
          } else if (result is Map) {
            pending.complete(Map<String, dynamic>.from(result));
          } else {
            pending.completeError(
              const FormatException('Invalid anchor compute result.'),
            );
          }
        }
    }
    _emitMetrics();
  }

  Future<void> _sendData(Map<String, dynamic> packet) async {
    final channel = _dataChannel;
    if (channel == null || !isOpen) {
      throw StateError('Anchor compute data channel is not open.');
    }
    final encoded = jsonEncode(packet);
    final bytes = utf8.encode(encoded).length;
    if (bytes > maxMessageBytes) {
      throw RangeError.range(bytes, 0, maxMessageBytes, 'messageBytes');
    }
    await channel.send(RTCDataChannelMessage(encoded));
    _bytesSent += bytes;
    _emitMetrics();
  }

  void _emitMetrics() => _metrics.add(
    AnchorComputeMetrics(
      bytesSent: _bytesSent,
      bytesReceived: _bytesReceived,
      lastLatency: _lastLatency,
      throughputBytesPerSecond:
          (_bytesSent + _bytesReceived) /
          (_clock().difference(_openedAt).inMicroseconds /
                  Duration.microsecondsPerSecond)
              .clamp(.001, double.infinity),
    ),
  );

  void _failPending(Object error) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
  }

  Future<void> close() async {
    _failPending(StateError('Anchor compute channel closed.'));
    await _signalSubscription?.cancel();
    await _dataChannel?.close();
    await _connection?.close();
    await _connection?.dispose();
    await _requests.close();
    await _metrics.close();
    await _connectivity.close();
  }
}

final class AnchorComputeCoordinator {
  AnchorComputeCoordinator({
    required this.router,
    required this.identity,
    this.onPeerMetrics,
    this.onPeerConnectionChanged,
  });

  final HivemindPeerRouter router;
  final MeshIdentityService identity;
  final void Function(String peerId, AnchorComputeMetrics metrics)?
  onPeerMetrics;
  final void Function(String peerId, bool connected)? onPeerConnectionChanged;
  final Map<String, AnchorComputeChannel> _channels = {};
  final StreamController<AnchorComputeRequest> _requests =
      StreamController<AnchorComputeRequest>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _paused = false;

  Stream<AnchorComputeRequest> get requests => _requests.stream;
  void setPaused(bool value) => _paused = value;
  List<String> get connectedAnchorIds => _channels.entries
      .where((entry) => entry.value.isOpen)
      .map((entry) => entry.key)
      .toList(growable: false);

  Future<void> start() async {
    final localId = (await identity.identity()).deviceId;
    _subscriptions.add(
      router.connectedChannels.listen((connection) {
        if (_channels.containsKey(connection.peerId)) return;
        final channel = AnchorComputeChannel(
          peerId: connection.peerId,
          signaling: connection.channel,
          initiator: localId.compareTo(connection.peerId) < 0,
        );
        _channels[connection.peerId] = channel;
        _subscriptions.add(channel.requests.listen(_requests.add));
        _subscriptions.add(
          channel.metrics.listen(
            (metrics) => onPeerMetrics?.call(connection.peerId, metrics),
          ),
        );
        _subscriptions.add(
          channel.connectivity.listen(
            (connected) => onPeerConnectionChanged?.call(
              connection.peerId,
              connected || connectedAnchorIds.isNotEmpty,
            ),
          ),
        );
        unawaited(
          channel.connect().catchError((Object _) async {
            _channels.remove(connection.peerId);
            await channel.close();
          }),
        );
      }),
    );
  }

  Future<Map<String, dynamic>?> delegate({
    required AnchorComputeJobKind kind,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (_paused) return null;
    final channel = _channels.values.where((value) => value.isOpen).firstOrNull;
    if (channel == null) return null;
    return channel.delegate(kind: kind, payload: payload, timeout: timeout);
  }

  void serve(AnchorComputeRequestHandler handler) {
    _subscriptions.add(
      requests.listen((request) async {
        try {
          if (_paused) throw StateError('Sanctuary Core is locked.');
          await respond(request.peerId, request.id, await handler(request));
        } on Object catch (error) {
          await respond(request.peerId, request.id, const {}, error: '$error');
        }
      }),
    );
  }

  Future<void> respond(
    String peerId,
    String requestId,
    Map<String, dynamic> result, {
    String? error,
  }) async {
    final channel = _channels[peerId];
    if (channel == null) throw StateError('Anchor peer is disconnected.');
    await channel.respond(requestId, result, error: error);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final channel in _channels.values) {
      await channel.close();
    }
    await _requests.close();
  }
}
