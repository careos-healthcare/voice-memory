/// Neutral trust-forward copy for evidence-backed insight cards.
abstract final class EvidenceTrustCopy {
  EvidenceTrustCopy._();

  static const archiveNoticed = 'Your archive noticed';
  static const viewSourceProof = 'View Source Proof';
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
