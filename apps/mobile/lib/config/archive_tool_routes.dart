/// Archive drawer tools — v1 surfaces only (belief survival / accuracy / contradictions deferred).
class ArchiveToolRoutes {
  ArchiveToolRoutes._();

  static const beliefSurvival = '/archive-tool/belief-survival';
  static const accuracy = '/archive-tool/accuracy';
  static const contradictions = '/archive-tool/contradictions';

  /// Incomplete on mobile — hidden from navigation; deep links redirect to archive home.
  static const Set<String> deferredToolPaths = {
    beliefSurvival,
    accuracy,
    contradictions,
  };

  static bool isDeferred(String path) =>
      deferredToolPaths.contains(path) || path.startsWith('/archive-tool/');
}