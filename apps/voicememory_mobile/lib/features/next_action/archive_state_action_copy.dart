/// Canonical archive state → user action labels.
abstract final class ArchiveStateActionCopy {
  ArchiveStateActionCopy._();

  static const noEntries = 'Record one real moment';
  static const oneEntry = 'Come back when this shows up again';
  static const twoUnrelated = 'Record the next real moment';
  static const twoRelated = 'Record one more related moment';
  static const firstProof = 'Record when it returns';
  static const returnCheckUnanswered = 'Answer return check';
  static const returnCheckAnswered = 'View what changed';
  static const patternChanged = 'Record when it returns';
  static const helpfulActionAppeared = 'Watch whether it appears again';
  static const privateReportForming = 'Keep the evidence trail going';

  /// Subordinate “Next:” line shown on Record and Patterns surfaces.
  static String nextLine(String action) {
    final normalized = action.endsWith('.') ? action : '$action.';
    final lowerFirst =
        '${normalized[0].toLowerCase()}${normalized.substring(1)}';
    return 'Next: $lowerFirst';
  }

  static List<String> get allActionLabels => [
        noEntries,
        oneEntry,
        twoUnrelated,
        twoRelated,
        firstProof,
        returnCheckUnanswered,
        returnCheckAnswered,
        patternChanged,
        helpfulActionAppeared,
        privateReportForming,
      ];
}
