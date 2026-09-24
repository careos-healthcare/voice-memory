/// Canonical safe-sharing copy — display and docs only, no sharing logic.
abstract final class SafeSharingCopy {
  SafeSharingCopy._();

  static const shareOnlyWhatYouChoose = 'Share only what you choose.';

  static const privateReportExplainPattern =
      'A private report may help you explain a pattern to someone you trust.';

  static const noDiagnosisDisclaimer =
      'ArchiveMe does not diagnose, treat, or replace professional support.';

  static const userControlIncluded = 'You stay in control of what is included.';

  static const futureSharingPrinciple =
      'Future sharing should be explicit, private, and reversible.';

  static const futureFeatureLabel =
      'Private sharing with someone you trust is a planned future direction — not available in the app yet.';

  static const foundationHeadline =
      'Talk about patterns with someone you trust';

  static const foundationBody =
      'ArchiveMe may help you explain evidence from saved moments — only if and when you choose to share.';

  /// Terms that must never appear in consumer-facing safe-sharing copy.
  static const bannedTerms = <String>[
    'therapy',
    'therapist dashboard',
    'clinical report',
    'diagnosis',
    'treatment',
    'mental health assessment',
    'medical record',
    'care plan',
    'doctor-ready diagnosis',
  ];

  static List<String> allVisibleStrings() => [
    shareOnlyWhatYouChoose,
    privateReportExplainPattern,
    noDiagnosisDisclaimer,
    userControlIncluded,
    futureSharingPrinciple,
    futureFeatureLabel,
    foundationHeadline,
    foundationBody,
  ];

  static bool containsConsentLanguage(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    return blob.contains('choose') &&
        (blob.contains('control') || blob.contains('only share'));
  }

  static bool hasNoBannedTerms(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    for (final term in bannedTerms) {
      if (blob.contains(term)) return false;
    }
    return true;
  }

  static bool labelsFutureFeature(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    return blob.contains('future') ||
        blob.contains('planned') ||
        blob.contains('not available');
  }
}
