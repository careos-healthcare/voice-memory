/// How a nearby device is keeping up with this archive.
enum MeshPeerSync { inSync, catchingUp, idle }

/// A device seen by a local mesh scan.
class MeshPeer {
  const MeshPeer({
    required this.id,
    required this.name,
    required this.ping,
    required this.sync,
    this.bytesPerSecondIn = 0,
    this.bytesPerSecondOut = 0,
  });

  final String id;
  final String name;
  final Duration ping;
  final MeshPeerSync sync;
  final int bytesPerSecondIn;
  final int bytesPerSecondOut;
}

/// Live mesh snapshot for the status center.
class MeshSyncState {
  const MeshSyncState({
    required this.meshEnabled,
    required this.peers,
    required this.bytesPerSecondIn,
    required this.bytesPerSecondOut,
    required this.pendingVectors,
    required this.completedVectors,
    required this.keyValid,
    required this.keyFingerprint,
    required this.loggingEnabled,
    required this.logs,
  });

  factory MeshSyncState.initial({required bool meshEnabled}) {
    return MeshSyncState(
      meshEnabled: meshEnabled,
      peers: const [],
      bytesPerSecondIn: 0,
      bytesPerSecondOut: 0,
      pendingVectors: 0,
      completedVectors: 0,
      keyValid: false,
      keyFingerprint: '',
      loggingEnabled: false,
      logs: const [],
    );
  }

  final bool meshEnabled;
  final List<MeshPeer> peers;
  final int bytesPerSecondIn;
  final int bytesPerSecondOut;
  final int pendingVectors;
  final int completedVectors;
  final bool keyValid;
  final String keyFingerprint;
  final bool loggingEnabled;
  final List<String> logs;

  int get vectorTotal => pendingVectors + completedVectors;

  double get queueFraction {
    final total = vectorTotal;
    if (total == 0) return 1;
    return completedVectors / total;
  }

  MeshSyncState copyWith({
    bool? meshEnabled,
    List<MeshPeer>? peers,
    int? bytesPerSecondIn,
    int? bytesPerSecondOut,
    int? pendingVectors,
    int? completedVectors,
    bool? keyValid,
    String? keyFingerprint,
    bool? loggingEnabled,
    List<String>? logs,
  }) {
    return MeshSyncState(
      meshEnabled: meshEnabled ?? this.meshEnabled,
      peers: peers ?? this.peers,
      bytesPerSecondIn: bytesPerSecondIn ?? this.bytesPerSecondIn,
      bytesPerSecondOut: bytesPerSecondOut ?? this.bytesPerSecondOut,
      pendingVectors: pendingVectors ?? this.pendingVectors,
      completedVectors: completedVectors ?? this.completedVectors,
      keyValid: keyValid ?? this.keyValid,
      keyFingerprint: keyFingerprint ?? this.keyFingerprint,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      logs: logs ?? this.logs,
    );
  }
}
