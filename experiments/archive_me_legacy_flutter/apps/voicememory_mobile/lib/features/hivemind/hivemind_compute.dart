import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../../core/llm/native/llama_inference_session.dart';
import '../../core/llm/semantic_extraction_result.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../services/security/mesh_identity_service.dart';
import '../../services/p2p_mesh/anchor_compute_channel.dart';
import '../../services/p2p_mesh/task_router.dart';
import '../p2p_mesh/mesh_trust_store.dart';
import '../p2p_mesh/sync/peer_sync_channel.dart';
import 'hivemind_mesh_router.dart';
import 'hivemind_models.dart';

enum HivemindComputeKind { embedding, semanticExtraction }

final class HivemindComputeException implements Exception {
  const HivemindComputeException(this.message);
  final String message;
  @override
  String toString() => 'HivemindComputeException: $message';
}

final class HivemindComputeDispatcher {
  HivemindComputeDispatcher({
    required this.router,
    required this.identity,
    required this.trustStore,
    required this.embeddingDriver,
    required this.embeddingModelFingerprint,
    required this.llama,
    required this.llmModelFingerprint,
    this.anchorCompute,
    this.taskRouter,
  });

  static const maxPayloadBytes = 32 * 1024;
  final HivemindPeerRouter router;
  final MeshIdentityService identity;
  final MeshTrustStore trustStore;
  final LocalEmbeddingDriver embeddingDriver;
  final String embeddingModelFingerprint;
  final LlamaInferenceSession llama;
  final String llmModelFingerprint;
  final AnchorComputeCoordinator? anchorCompute;
  final TaskRouter? taskRouter;
  final Map<String, AuthenticatedPeerSyncChannel> _channels = {};
  final Map<String, _PendingCompute> _pending = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _nonce = 0;
  bool _paused = false;

  void setPaused(bool paused) => _paused = paused;

  void start() {
    _subscriptions.add(
      router.connectedChannels.listen((connection) {
        _channels[connection.peerId] = connection.channel;
        _subscriptions.add(
          connection.channel.packets.listen(
            (packet) => unawaited(_handleResult(connection.peerId, packet)),
            onDone: () => _disconnect(connection.peerId),
          ),
        );
      }),
    );
  }

  Future<List<Float32List>> embed(
    List<String> texts, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (texts.isEmpty || texts.length > 64) {
      throw RangeError.range(texts.length, 1, 64, 'texts.length');
    }
    List<Float32List> local() =>
        texts.map(embeddingDriver.embed).toList(growable: false);
    Future<List<Float32List>> fallback() async {
      final peer = _eligiblePeer(
        (peer) => peer.embeddingFingerprint == embeddingModelFingerprint,
      );
      if (peer == null) return local();
      try {
        final result = await _dispatch(
          peer: peer,
          kind: HivemindComputeKind.embedding,
          payload: {'texts': texts},
          bounds: {
            'batch': texts.length,
            'dimensions': embeddingDriver.dimensions,
          },
          modelFingerprint: embeddingModelFingerprint,
          timeout: timeout,
        );
        return _embeddingVectors(result, texts.length);
      } on Object {
        return local();
      }
    }

    final interceptor = taskRouter;
    if (interceptor != null) {
      final routed = await interceptor.submit<List<Float32List>>(
        kind: RoutedComputeKind.embedding,
        payload: {'texts': texts},
        runLocal: fallback,
        decodeRemote: (result) => _embeddingVectors(result, texts.length),
        timeout: timeout,
      );
      final value = routed.value;
      if (value != null) return value;
      throw HivemindComputeException(
        'Embedding job deferred to encrypted backlog ${routed.backlogId}.',
      );
    }
    if (!_paused && router.governance.computeOffloadEnabled) {
      try {
        final result = await anchorCompute?.delegate(
          kind: AnchorComputeJobKind.batchEmbeddings,
          payload: {'texts': texts},
          timeout: timeout,
        );
        if (result != null) return _embeddingVectors(result, texts.length);
      } on Object {
        // Fall through to the existing signed channel or local execution.
      }
    }
    return fallback();
  }

  Future<SemanticExtractionResult> extract(
    String text, {
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Future<SemanticExtractionResult> local() =>
        llama.infer(text, maxTokens: maxTokens, timeout: timeout);
    Future<SemanticExtractionResult> fallback() async {
      final peer = _eligiblePeer(
        (peer) => peer.llmFingerprint == llmModelFingerprint,
      );
      if (peer == null) return local();
      try {
        final result = await _dispatch(
          peer: peer,
          kind: HivemindComputeKind.semanticExtraction,
          payload: {'text': text},
          bounds: {'maxTokens': maxTokens},
          modelFingerprint: llmModelFingerprint,
          timeout: timeout,
        );
        final extraction = SemanticExtractionResult.fromJson(result);
        if (!extraction.isValid) {
          throw const FormatException('Remote semantic extraction is invalid.');
        }
        return extraction;
      } on Object {
        return local();
      }
    }

    final interceptor = taskRouter;
    if (interceptor != null) {
      final routed = await interceptor.submit<SemanticExtractionResult>(
        kind: RoutedComputeKind.llama,
        payload: {'text': text, 'maxTokens': maxTokens},
        runLocal: fallback,
        decodeRemote: (result) {
          final extraction = SemanticExtractionResult.fromJson(result);
          if (!extraction.isValid) {
            throw const FormatException(
              'Remote semantic extraction is invalid.',
            );
          }
          return extraction;
        },
        timeout: timeout,
      );
      final value = routed.value;
      if (value != null) return value;
      throw HivemindComputeException(
        'Llama job deferred to encrypted backlog ${routed.backlogId}.',
      );
    }
    if (!_paused && router.governance.computeOffloadEnabled) {
      try {
        final result = await anchorCompute?.delegate(
          kind: AnchorComputeJobKind.llamaCouncil,
          payload: {'text': text, 'maxTokens': maxTokens},
          timeout: timeout,
        );
        if (result != null) {
          final extraction = SemanticExtractionResult.fromJson(result);
          if (extraction.isValid) return extraction;
        }
      } on Object {
        // Fall through to the existing signed channel or local execution.
      }
    }
    return fallback();
  }

  List<Float32List> _embeddingVectors(
    Map<String, dynamic> result,
    int expectedCount,
  ) {
    final vectors = result['vectors'];
    if (vectors is! List || vectors.length != expectedCount) {
      throw const FormatException('Embedding result batch is invalid.');
    }
    return vectors
        .map((raw) {
          if (raw is! List || raw.length != embeddingDriver.dimensions) {
            throw const FormatException('Embedding dimensions are invalid.');
          }
          final values = raw.map((value) => (value as num).toDouble()).toList();
          if (values.any((value) => !value.isFinite)) {
            throw const FormatException(
              'Embedding contains non-finite values.',
            );
          }
          return Float32List.fromList(values);
        })
        .toList(growable: false);
  }

  HivemindPeerState? _eligiblePeer(
    bool Function(HivemindPeerState peer) supports,
  ) {
    if (_paused || !router.governance.computeOffloadEnabled) return null;
    return router.currentPeers.where((peer) {
      return peer.connected &&
          peer.trusted &&
          peer.offloadAccepted &&
          peer.gpuState == HivemindGpuState.idle &&
          supports(peer) &&
          _channels.containsKey(peer.peerId);
    }).firstOrNull;
  }

  Future<Map<String, dynamic>> _dispatch({
    required HivemindPeerState peer,
    required HivemindComputeKind kind,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> bounds,
    required String modelFingerprint,
    required Duration timeout,
  }) async {
    final channel = _channels[peer.peerId];
    if (channel == null) throw StateError('Peer disconnected.');
    final localIdentity = await identity.identity();
    final nonce = '${localIdentity.deviceId}:${++_nonce}';
    final deadline = DateTime.now().toUtc().add(timeout);
    final payloadBytes = _canonicalBytes(payload);
    if (payloadBytes.length > maxPayloadBytes) {
      throw const HivemindComputeException('Compute payload is too large.');
    }
    final signed = {
      'version': 1,
      'source': localIdentity.deviceId,
      'target': peer.peerId,
      'kind': kind.name,
      'payloadHash': sha256.convert(payloadBytes).toString(),
      'deadline': deadline.toIso8601String(),
      'bounds': bounds,
      'modelFingerprint': modelFingerprint,
      'nonce': nonce,
    };
    final signature = await identity.signDetached(_canonicalBytes(signed));
    final pending = _PendingCompute(
      peerId: peer.peerId,
      kind: kind.name,
      modelFingerprint: modelFingerprint,
    );
    _pending[nonce] = pending;
    await channel.send({
      ...signed,
      'type': 'hivemind_compute_request',
      'payload': payload,
      'signature': base64UrlEncode(signature),
    });
    try {
      return await pending.completer.future.timeout(timeout);
    } finally {
      _pending.remove(nonce);
    }
  }

  Future<void> _handleResult(String peerId, Map<String, dynamic> packet) async {
    if (packet['type'] != 'hivemind_compute_result' ||
        packet['version'] != 1 ||
        packet['nonce'] is! String ||
        packet['result'] is! Map) {
      return;
    }
    final nonce = packet['nonce'] as String;
    final pending = _pending[nonce];
    if (pending == null) return;
    try {
      final peer = await trustStore.find(peerId);
      final localIdentity = await identity.identity();
      if (peer == null ||
          packet['source'] != peerId ||
          packet['target'] != localIdentity.deviceId ||
          pending.peerId != peerId ||
          packet['kind'] != pending.kind ||
          packet['modelFingerprint'] != pending.modelFingerprint) {
        throw const HivemindComputeException('Untrusted compute result.');
      }
      final result = Map<String, dynamic>.from(packet['result'] as Map);
      final bytes = _canonicalBytes(result);
      if (sha256.convert(bytes).toString() != packet['resultHash']) {
        throw const HivemindComputeException('Compute result hash mismatch.');
      }
      final signature = base64Url.decode('${packet['signature']}');
      if (!await _verify(
        _resultSigningFields(packet),
        signature,
        peer.identityPublicKey,
      )) {
        throw const HivemindComputeException(
          'Compute result signature failed.',
        );
      }
      if (!pending.completer.isCompleted) pending.completer.complete(result);
    } on Object catch (error, stackTrace) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error, stackTrace);
      }
    }
  }

  void _disconnect(String peerId) {
    _channels.remove(peerId);
    for (final pending in _pending.values.where(
      (pending) => pending.peerId == peerId,
    )) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          StateError('Compute peer disconnected.'),
        );
      }
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

final class _PendingCompute {
  _PendingCompute({
    required this.peerId,
    required this.kind,
    required this.modelFingerprint,
  });

  final String peerId;
  final String kind;
  final String modelFingerprint;
  final Completer<Map<String, dynamic>> completer = Completer();
}

final class HivemindRemoteComputeExecutor {
  HivemindRemoteComputeExecutor({
    required this.router,
    required this.identity,
    required this.trustStore,
    required this.embeddingDriver,
    required this.embeddingModelFingerprint,
    required this.llama,
    required this.llmModelFingerprint,
  });

  final HivemindPeerRouter router;
  final MeshIdentityService identity;
  final MeshTrustStore trustStore;
  final LocalEmbeddingDriver embeddingDriver;
  final String embeddingModelFingerprint;
  final LlamaInferenceSession llama;
  final String llmModelFingerprint;
  final Set<String> _seenNonces = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _paused = false;

  void setPaused(bool paused) => _paused = paused;

  void start() {
    _subscriptions.add(
      router.connectedChannels.listen((connection) {
        _subscriptions.add(
          connection.channel.packets.listen(
            (packet) => unawaited(
              _handle(connection.peerId, connection.channel, packet),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _handle(
    String peerId,
    AuthenticatedPeerSyncChannel channel,
    Map<String, dynamic> packet,
  ) async {
    if (_paused || packet['type'] != 'hivemind_compute_request') return;
    try {
      if (!router.governance.acceptRemoteCompute ||
          packet['version'] != 1 ||
          packet['source'] != peerId ||
          packet['payload'] is! Map ||
          packet['bounds'] is! Map ||
          packet['nonce'] is! String) {
        throw const HivemindComputeException('Compute request is not allowed.');
      }
      final localIdentity = await identity.identity();
      if (packet['target'] != localIdentity.deviceId) {
        throw const HivemindComputeException('Compute target is invalid.');
      }
      final nonce = packet['nonce'] as String;
      if (!_seenNonces.add(nonce)) {
        throw const HivemindComputeException('Compute request replayed.');
      }
      if (_seenNonces.length > 1024) _seenNonces.remove(_seenNonces.first);
      final deadline = DateTime.tryParse('${packet['deadline']}')?.toUtc();
      if (deadline == null || !deadline.isAfter(DateTime.now().toUtc())) {
        throw const HivemindComputeException('Compute request expired.');
      }
      final peer = await trustStore.find(peerId);
      if (peer == null) {
        throw const HivemindComputeException('Compute peer is untrusted.');
      }
      final payload = Map<String, dynamic>.from(packet['payload'] as Map);
      final payloadBytes = _canonicalBytes(payload);
      if (payloadBytes.length > HivemindComputeDispatcher.maxPayloadBytes ||
          sha256.convert(payloadBytes).toString() != packet['payloadHash']) {
        throw const HivemindComputeException('Compute payload is invalid.');
      }
      final signature = base64Url.decode('${packet['signature']}');
      if (!await _verify(
        _requestSigningFields(packet),
        signature,
        peer.identityPublicKey,
      )) {
        throw const HivemindComputeException('Compute signature failed.');
      }
      final result = await _execute(packet, payload, deadline);
      final resultBytes = _canonicalBytes(result);
      final signed = {
        'version': 1,
        'source': localIdentity.deviceId,
        'target': peerId,
        'kind': packet['kind'],
        'resultHash': sha256.convert(resultBytes).toString(),
        'modelFingerprint': packet['modelFingerprint'],
        'nonce': nonce,
      };
      final resultSignature = await identity.signDetached(
        _canonicalBytes(signed),
      );
      await channel.send({
        ...signed,
        'type': 'hivemind_compute_result',
        'result': result,
        'signature': base64UrlEncode(resultSignature),
      });
    } on Object {
      // Fail closed; the requester times out and executes locally.
    }
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> packet,
    Map<String, dynamic> payload,
    DateTime deadline,
  ) async {
    final remaining = deadline.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      throw const HivemindComputeException('Compute request expired.');
    }
    switch (packet['kind']) {
      case 'embedding':
        if (packet['modelFingerprint'] != embeddingModelFingerprint) {
          throw const HivemindComputeException('Embedding model mismatch.');
        }
        final texts = (payload['texts'] as List?)?.whereType<String>().toList();
        final bounds = Map<String, dynamic>.from(packet['bounds'] as Map);
        if (texts == null ||
            texts.isEmpty ||
            texts.length > 64 ||
            bounds['batch'] != texts.length ||
            bounds['dimensions'] != embeddingDriver.dimensions) {
          throw const HivemindComputeException('Embedding bounds are invalid.');
        }
        return {
          'vectors': texts
              .map((text) => embeddingDriver.embed(text).toList())
              .toList(),
        };
      case 'semanticExtraction':
        if (packet['modelFingerprint'] != llmModelFingerprint) {
          throw const HivemindComputeException('LLM model mismatch.');
        }
        final text = payload['text'];
        final maxTokens = (packet['bounds'] as Map)['maxTokens'] as int? ?? 256;
        if (text is! String ||
            text.isEmpty ||
            text.length > LlamaInferenceSession.maxInputCharacters ||
            maxTokens < 1 ||
            maxTokens > 512) {
          throw const HivemindComputeException('LLM bounds are invalid.');
        }
        final result = await llama.infer(
          text,
          maxTokens: maxTokens,
          timeout: remaining,
        );
        if (!result.isValid) {
          throw const HivemindComputeException('LLM result is invalid.');
        }
        return result.toJson();
      default:
        throw const HivemindComputeException('Unsupported compute job.');
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

Map<String, dynamic> _requestSigningFields(Map<String, dynamic> packet) => {
  'version': packet['version'],
  'source': packet['source'],
  'target': packet['target'],
  'kind': packet['kind'],
  'payloadHash': packet['payloadHash'],
  'deadline': packet['deadline'],
  'bounds': packet['bounds'],
  'modelFingerprint': packet['modelFingerprint'],
  'nonce': packet['nonce'],
};

Map<String, dynamic> _resultSigningFields(Map<String, dynamic> packet) => {
  'version': packet['version'],
  'source': packet['source'],
  'target': packet['target'],
  'kind': packet['kind'],
  'resultHash': packet['resultHash'],
  'modelFingerprint': packet['modelFingerprint'],
  'nonce': packet['nonce'],
};

Future<bool> _verify(
  Map<String, dynamic> fields,
  List<int> signature,
  List<int> publicKey,
) => Ed25519().verify(
  _canonicalBytes(fields),
  signature: Signature(
    signature,
    publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
  ),
);

List<int> _canonicalBytes(Object? value) => utf8.encode(_canonicalJson(value));

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
