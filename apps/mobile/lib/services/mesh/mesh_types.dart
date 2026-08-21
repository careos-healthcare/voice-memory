/// Shared mesh compute types for local P2P llama.cpp offloading.
library;

/// Role advertised during mesh capability handshake.
enum MeshPeerRole {
  mobile,
  desktop,
}

/// Compute resources a mesh peer can offer for llama.cpp inference.
enum MeshComputeResource {
  cpu,
  gpu,
}

/// Where an inference request was executed.
enum LlamaInferenceRoute {
  meshPeer,
  onDevice,
}

/// Why mesh offloading was skipped and local inference was used.
enum MeshOffloadFallbackReason {
  featureDisabled,
  capabilityDisabled,
  localNetworkPermissionDenied,
  noCapablePeer,
  handshakeTimeout,
  handshakeFailed,
  inferenceTimeout,
  transportError,
  peerRejected,
}

/// Capability snapshot exchanged during mesh handshake.
class MeshPeerCapabilities {
  const MeshPeerCapabilities({
    required this.peerId,
    required this.role,
    required this.host,
    required this.port,
    this.llamaCppSupported = false,
    this.llamaCppVersion,
    this.resources = const {},
    this.maxContextTokens,
    this.active = true,
  });

  factory MeshPeerCapabilities.fromJson(Map<String, dynamic> json) {
    final rawResources = json['resources'];
    final resources = <MeshComputeResource>{};
    if (rawResources is List) {
      for (final item in rawResources) {
        final parsed = MeshComputeResource.values.asNameMap()[item];
        if (parsed != null) resources.add(parsed);
      }
    }

    return MeshPeerCapabilities(
      peerId: json['peerId'] as String? ?? '',
      role: MeshPeerRole.values.asNameMap()[json['role']] ?? MeshPeerRole.desktop,
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      llamaCppSupported: json['llamaCppSupported'] as bool? ?? false,
      llamaCppVersion: json['llamaCppVersion'] as String?,
      resources: resources,
      maxContextTokens: json['maxContextTokens'] as int?,
      active: json['active'] as bool? ?? true,
    );
  }

  final String peerId;
  final MeshPeerRole role;
  final String host;
  final int port;
  final bool llamaCppSupported;
  final String? llamaCppVersion;
  final Set<MeshComputeResource> resources;
  final int? maxContextTokens;
  final bool active;

  bool get isDesktopLlamaPeer =>
      role == MeshPeerRole.desktop &&
      active &&
      llamaCppSupported &&
      host.isNotEmpty &&
      port > 0;

  bool get prefersGpu => resources.contains(MeshComputeResource.gpu);

  Map<String, dynamic> toJson() => {
    'peerId': peerId,
    'role': role.name,
    'host': host,
    'port': port,
    'llamaCppSupported': llamaCppSupported,
    if (llamaCppVersion != null) 'llamaCppVersion': llamaCppVersion,
    'resources': resources.map((r) => r.name).toList(),
    if (maxContextTokens != null) 'maxContextTokens': maxContextTokens,
    'active': active,
  };
}

/// Payload routed to a mesh peer or local llama.cpp runtime.
class LlamaInferenceRequest {
  const LlamaInferenceRequest({
    required this.prompt,
    this.maxTokens = 256,
    this.temperature = 0.7,
    this.modelId,
  });

  factory LlamaInferenceRequest.fromJson(Map<String, dynamic> json) {
    return LlamaInferenceRequest(
      prompt: json['prompt'] as String? ?? '',
      maxTokens: json['maxTokens'] as int? ?? 256,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      modelId: json['modelId'] as String?,
    );
  }

  final String prompt;
  final int maxTokens;
  final double temperature;
  final String? modelId;

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'maxTokens': maxTokens,
    'temperature': temperature,
    if (modelId != null) 'modelId': modelId,
  };
}

/// Inference output from mesh or on-device llama.cpp.
class LlamaInferenceResponse {
  const LlamaInferenceResponse({
    required this.text,
    required this.route,
    this.peerId,
    this.tokensUsed,
    this.fallbackReason,
  });

  final String text;
  final LlamaInferenceRoute route;
  final String? peerId;
  final int? tokensUsed;
  final MeshOffloadFallbackReason? fallbackReason;

  bool get usedMeshPeer => route == LlamaInferenceRoute.meshPeer;
}

/// Ranked mesh peer after discovery + handshake.
class MeshPeerSession {
  const MeshPeerSession({
    required this.capabilities,
    required this.sessionKeyBytes,
    this.handshakeNonce,
  });

  final MeshPeerCapabilities capabilities;
  final List<int> sessionKeyBytes;
  final String? handshakeNonce;
}
