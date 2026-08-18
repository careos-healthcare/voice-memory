/// JSON-framed mesh compute messages for capability handshake and inference.
library;

import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

abstract final class MeshComputeMessageTypes {
  MeshComputeMessageTypes._();

  static const handshakeRequest = 'mesh.handshake.request';
  static const handshakeResponse = 'mesh.handshake.response';
  static const inferenceRequest = 'mesh.inference.request';
  static const inferenceResponse = 'mesh.inference.response';
  static const error = 'mesh.error';
}

class MeshHandshakeRequest {
  const MeshHandshakeRequest({
    required this.clientId,
    required this.nonce,
    required this.capabilities,
  });

  factory MeshHandshakeRequest.fromJson(Map<String, dynamic> json) {
    return MeshHandshakeRequest(
      clientId: json['clientId'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      capabilities: MeshPeerCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  final String clientId;
  final String nonce;
  final MeshPeerCapabilities capabilities;

  Map<String, dynamic> toJson() => {
    'type': MeshComputeMessageTypes.handshakeRequest,
    'clientId': clientId,
    'nonce': nonce,
    'capabilities': capabilities.toJson(),
  };
}

class MeshHandshakeResponse {
  const MeshHandshakeResponse({
    required this.peerId,
    required this.nonce,
    required this.capabilities,
    this.accepted = true,
    this.rejectionReason,
  });

  factory MeshHandshakeResponse.fromJson(Map<String, dynamic> json) {
    return MeshHandshakeResponse(
      peerId: json['peerId'] as String? ?? '',
      nonce: json['nonce'] as String? ?? '',
      capabilities: MeshPeerCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      accepted: json['accepted'] as bool? ?? true,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  final String peerId;
  final String nonce;
  final MeshPeerCapabilities capabilities;
  final bool accepted;
  final String? rejectionReason;

  Map<String, dynamic> toJson() => {
    'type': MeshComputeMessageTypes.handshakeResponse,
    'peerId': peerId,
    'nonce': nonce,
    'capabilities': capabilities.toJson(),
    'accepted': accepted,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
  };
}

class MeshInferenceWireRequest {
  const MeshInferenceWireRequest({required this.request, required this.requestId});

  factory MeshInferenceWireRequest.fromJson(Map<String, dynamic> json) {
    return MeshInferenceWireRequest(
      requestId: json['requestId'] as String? ?? '',
      request: LlamaInferenceRequest.fromJson(
        (json['request'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  final String requestId;
  final LlamaInferenceRequest request;

  Map<String, dynamic> toJson() => {
    'type': MeshComputeMessageTypes.inferenceRequest,
    'requestId': requestId,
    'request': request.toJson(),
  };
}

class MeshInferenceWireResponse {
  const MeshInferenceWireResponse({
    required this.requestId,
    required this.text,
    this.tokensUsed,
    this.error,
  });

  factory MeshInferenceWireResponse.fromJson(Map<String, dynamic> json) {
    return MeshInferenceWireResponse(
      requestId: json['requestId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      tokensUsed: json['tokensUsed'] as int?,
      error: json['error'] as String?,
    );
  }

  final String requestId;
  final String text;
  final int? tokensUsed;
  final String? error;

  Map<String, dynamic> toJson() => {
    'type': MeshComputeMessageTypes.inferenceResponse,
    'requestId': requestId,
    'text': text,
    if (tokensUsed != null) 'tokensUsed': tokensUsed,
    if (error != null) 'error': error,
  };
}
