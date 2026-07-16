/// Presentation-only gates for Archive first-comparison (two-entry) UI.
abstract class ArchiveFirstComparisonUiGates {
  ArchiveFirstComparisonUiGates._();

  /// One calm proof card instead of competing early-signal stacks.
  static bool showCalmFirstComparisonCard({
    required int eligibleEntryCount,
  }) =>
      eligibleEntryCount == 2;
}
