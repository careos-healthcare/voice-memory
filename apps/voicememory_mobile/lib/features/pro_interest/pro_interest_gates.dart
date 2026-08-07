/// Visibility gates for Pro interest archive-home link.
abstract final class ProInterestGates {
  ProInterestGates._();

  static bool showArchiveLink({
    required int entryCount,
    required int watchlistCount,
    required bool sampleMode,
  }) => !sampleMode && (entryCount >= 10 || watchlistCount >= 3);
}
