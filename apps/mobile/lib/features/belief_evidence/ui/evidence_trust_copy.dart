/// Neutral trust-forward copy for evidence-backed insight cards.
abstract final class EvidenceTrustCopy {
  EvidenceTrustCopy._();

  static const archiveNoticed = 'Your archive noticed';

  /// Live label on the evidence trail control and source-proof sheet.
  static const String howWeKnow = 'How we know';

  /// Alternate source-data sense of the same control.
  static const String sourceData = 'Source Data';

  /// Canonical trail label. Alias of [howWeKnow] so existing finders
  /// and the sheet title stay on one string.
  static const String viewSourceProof = howWeKnow;
  static const transcriptExcerptLabel = 'Transcript excerpt';
  static const sheetLead =
      'Original transcript excerpts cited for this read.';

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
