enum HivemindTransportKind { nsdTcp, webRtc, ble, noiseXX }

final class HivemindTransportCapability {
  const HivemindTransportCapability({
    required this.kind,
    required this.available,
    required this.contractVersion,
    required this.backend,
    required this.reason,
  });

  const HivemindTransportCapability.unavailable(this.kind, this.reason)
    : available = false,
      contractVersion = 1,
      backend = 'unavailable';

  final HivemindTransportKind kind;
  final bool available;
  final int contractVersion;
  final String backend;
  final String reason;
}

enum HivemindDeviceKind { phone, tablet, desktop, unknown }

enum HivemindGpuState { unavailable, busy, idle, active }

final class HivemindPeerState {
  const HivemindPeerState({
    required this.peerId,
    required this.displayName,
    this.deviceKind = HivemindDeviceKind.unknown,
    this.gpuState = HivemindGpuState.unavailable,
    this.signalStrength = 0,
    this.latency = Duration.zero,
    this.connected = true,
    this.trusted = true,
    this.offloadAccepted = false,
    this.embeddingFingerprint,
    this.llmFingerprint,
    this.lastSeenAt,
    this.throughputBytesPerSecond = 0,
    this.transport = HivemindTransportKind.noiseXX,
  });

  final String peerId;
  final String displayName;
  final HivemindDeviceKind deviceKind;
  final HivemindGpuState gpuState;
  final double signalStrength;
  final Duration latency;
  final bool connected;
  final bool trusted;
  final bool offloadAccepted;
  final String? embeddingFingerprint;
  final String? llmFingerprint;
  final DateTime? lastSeenAt;
  final double throughputBytesPerSecond;
  final HivemindTransportKind transport;

  HivemindPeerState copyWith({
    Duration? latency,
    bool? connected,
    bool? offloadAccepted,
    HivemindGpuState? gpuState,
    String? embeddingFingerprint,
    String? llmFingerprint,
    DateTime? lastSeenAt,
    double? throughputBytesPerSecond,
    HivemindTransportKind? transport,
  }) => HivemindPeerState(
    peerId: peerId,
    displayName: displayName,
    deviceKind: deviceKind,
    gpuState: gpuState ?? this.gpuState,
    signalStrength: signalStrength,
    latency: latency ?? this.latency,
    connected: connected ?? this.connected,
    trusted: trusted,
    offloadAccepted: offloadAccepted ?? this.offloadAccepted,
    embeddingFingerprint: embeddingFingerprint ?? this.embeddingFingerprint,
    llmFingerprint: llmFingerprint ?? this.llmFingerprint,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    throughputBytesPerSecond:
        throughputBytesPerSecond ?? this.throughputBytesPerSecond,
    transport: transport ?? this.transport,
  );
}

final class HivemindGovernance {
  const HivemindGovernance({
    this.discoveryEnabled = false,
    this.computeOffloadEnabled = false,
    this.acceptRemoteCompute = false,
    this.automaticSyncEnabled = true,
  });

  final bool discoveryEnabled;
  final bool computeOffloadEnabled;
  final bool acceptRemoteCompute;
  final bool automaticSyncEnabled;

  HivemindGovernance copyWith({
    bool? discoveryEnabled,
    bool? computeOffloadEnabled,
    bool? acceptRemoteCompute,
    bool? automaticSyncEnabled,
  }) => HivemindGovernance(
    discoveryEnabled: discoveryEnabled ?? this.discoveryEnabled,
    computeOffloadEnabled: computeOffloadEnabled ?? this.computeOffloadEnabled,
    acceptRemoteCompute: acceptRemoteCompute ?? this.acceptRemoteCompute,
    automaticSyncEnabled: automaticSyncEnabled ?? this.automaticSyncEnabled,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'discoveryEnabled': discoveryEnabled,
    'computeOffloadEnabled': computeOffloadEnabled,
    'acceptRemoteCompute': acceptRemoteCompute,
    'automaticSyncEnabled': automaticSyncEnabled,
  };

  factory HivemindGovernance.fromJson(Map<String, dynamic> json) =>
      HivemindGovernance(
        discoveryEnabled: json['discoveryEnabled'] == true,
        computeOffloadEnabled: json['computeOffloadEnabled'] == true,
        acceptRemoteCompute: json['acceptRemoteCompute'] == true,
        automaticSyncEnabled: json['automaticSyncEnabled'] != false,
      );
}
