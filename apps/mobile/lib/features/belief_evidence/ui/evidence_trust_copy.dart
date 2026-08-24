/// Neutral trust-forward copy for evidence-backed insight cards.
abstract final class EvidenceTrustCopy {
  EvidenceTrustCopy._();

  static const archiveNoticed = 'Your archive noticed';

  /// Live label on the evidence trail control.
  static const String howWeKnow = 'How we know';

  /// Alternate source-data sense of the same control.
  static const String sourceData = 'Source Data';

  /// Sheet title. Longer than [howWeKnow] so the sheet reads as a
  /// pattern explanation, not a promise that quotes are waiting inside.
  static const String howWeKnowThisPattern = 'How we know this pattern';

  /// Canonical trail label. Alias of [howWeKnow] so existing finders
  /// stay on one string. The sheet uses [howWeKnowThisPattern].
  static const String viewSourceProof = howWeKnow;
  static const transcriptExcerptLabel = 'Transcript excerpt';
  static const sheetLead =
      'Original transcript excerpts cited for this read.';

  /// Honest empty body. Shown when a tap opens the sheet and there is
  /// no verified quote — never a stand-in sentence.
  static const String sourceQuotesUnavailable =
      'Source quotes are not available for this pattern.';

  /// Always-visible inline citation count (e.g. "3 sources").
  static String sourceCount(int count) {
    if (count <= 0) return '0 sources';
    if (count == 1) return '1 source';
    return '$count sources';
  }

  static String supportedByEntries(int count) {
    if (count <= 0) return 'No supporting entries yet';
    if (count == 1) return 'Supported by 1 entry';
    return 'Supported by $count entries';
  }
}
