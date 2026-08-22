/// User-facing copy for the evidence ledger header and inspect sheet.
abstract final class EvidenceLedgerCopy {
  EvidenceLedgerCopy._();

  static const sheetTitle = 'Evidence ledger';
  static const sheetSubtitle =
      'Possible patterns, changes, and evidence from your archive.';
  static const searchHint = 'Search moments, patterns, and evidence…';
  static const emptyTitle = 'No indexed evidence yet';
  static const emptyBody =
      'Save a moment and let ArchiveMe index citable facts — they will appear here.';
  static const filterAll = 'All time';
  static const filter7Days = '7 days';
  static const filter30Days = '30 days';
  static const filter90Days = '90 days';
  static const noMatches = 'Nothing matches your search or date filter.';

  static String badgeLabel({
    required int citableFactCount,
    required int entryCount,
  }) {
    final factsLabel =
        citableFactCount == 1 ? '1 Citable Fact' : '$citableFactCount Citable Facts';
    final entriesLabel = entryCount == 1 ? '1 Entry' : '$entryCount Entries';
    return '$factsLabel • $entriesLabel';
  }

  static String badgeSemantics({
    required int citableFactCount,
    required int entryCount,
  }) =>
      'Evidence ledger, $citableFactCount citable facts across $entryCount entries. Double tap to inspect.';
}