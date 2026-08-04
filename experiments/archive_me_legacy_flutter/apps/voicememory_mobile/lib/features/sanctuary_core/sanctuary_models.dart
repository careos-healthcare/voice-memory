enum SanctuaryCheckStatus { healthy, warning, failed, unavailable }

final class SanctuaryDiagnostic {
  const SanctuaryDiagnostic({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final SanctuaryCheckStatus status;
  final String detail;
}

enum SanctuaryStorageKind {
  memoryGraph,
  whisperAudio,
  embeddings,
  browserClips,
  backups,
  other,
}

final class SanctuaryStorageMetric {
  const SanctuaryStorageMetric({
    required this.kind,
    required this.bytes,
    required this.itemCount,
    required this.label,
  });

  final SanctuaryStorageKind kind;
  final int bytes;
  final int itemCount;
  final String label;
}

final class SanctuaryHealthReport {
  SanctuaryHealthReport({
    required this.generatedAt,
    required this.diagnostics,
    required this.storage,
    required this.cleanupRecommendations,
  });

  final DateTime generatedAt;
  final List<SanctuaryDiagnostic> diagnostics;
  final List<SanctuaryStorageMetric> storage;
  final List<String> cleanupRecommendations;

  int get totalBytes => storage.fold(0, (sum, item) => sum + item.bytes);
  int get healthyChecks => diagnostics
      .where((item) => item.status == SanctuaryCheckStatus.healthy)
      .length;
  bool get hasFailures =>
      diagnostics.any((item) => item.status == SanctuaryCheckStatus.failed);
  double get healthFraction {
    final assessed = diagnostics
        .where((item) => item.status != SanctuaryCheckStatus.unavailable)
        .toList();
    if (assessed.isEmpty) return 0;
    final score = assessed.fold<double>(
      0,
      (sum, item) =>
          sum +
          switch (item.status) {
            SanctuaryCheckStatus.healthy => 1,
            SanctuaryCheckStatus.warning => .5,
            _ => 0,
          },
    );
    return score / assessed.length;
  }
}

final class SanctuaryGovernanceState {
  const SanctuaryGovernanceState({
    required this.museEnabled,
    required this.browserBridgeEnabled,
    required this.peerDiscoveryEnabled,
  });

  final bool museEnabled;
  final bool browserBridgeEnabled;
  final bool peerDiscoveryEnabled;

  SanctuaryGovernanceState copyWith({
    bool? museEnabled,
    bool? browserBridgeEnabled,
    bool? peerDiscoveryEnabled,
  }) => SanctuaryGovernanceState(
    museEnabled: museEnabled ?? this.museEnabled,
    browserBridgeEnabled: browserBridgeEnabled ?? this.browserBridgeEnabled,
    peerDiscoveryEnabled: peerDiscoveryEnabled ?? this.peerDiscoveryEnabled,
  );
}
