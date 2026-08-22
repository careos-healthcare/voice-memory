/// Copy for the dedicated comparison explorer screen.
abstract final class ComparisonExplorerCopy {
  ComparisonExplorerCopy._();

  static const String screenTitle = 'Pattern comparison';

  static const String launchFromChanges = 'Explore how you have changed';

  static const String windowSectionTitle = 'Time range';

  static const String freeTrailHelper =
      'Free shows one prior moment with full citation quotes in this range. '
      'Pro unlocks the complete thread.';

  static const String insufficientMomentsTitle = 'Not enough history yet';

  static String insufficientMomentsBody(String windowLabel) =>
      'Save at least two moments in $windowLabel to compare how your archive evolved.';

  static const String emptyArchiveBody =
      'Your first saved moments will appear here once you start recording.';

  static const String loadingComparison = 'Analyzing your archive…';

  static String momentCountLabel(int count) =>
      count == 1 ? '1 moment in range' : '$count moments in range';
}