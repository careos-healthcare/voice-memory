/// Neutral trust-forward copy for evidence-backed insight cards.
abstract final class EvidenceTrustCopy {
  EvidenceTrustCopy._();

  static const archiveNoticed = 'Your archive noticed';
  static const viewSourceProof = 'View Source Proof';
  static const hideSourceProof = 'Hide Source Proof';
  static const yourWordsLabel = 'In your own words';

  static String supportedByEntries(int count) {
    if (count <= 0) return 'No supporting entries yet';
    if (count == 1) return 'Supported by 1 entry';
    return 'Supported by $count entries';
  }
}
