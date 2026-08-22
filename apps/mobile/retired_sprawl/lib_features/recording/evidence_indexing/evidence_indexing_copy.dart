/// Copy for the evidence indexing post-save transition.
abstract final class EvidenceIndexingCopy {
  EvidenceIndexingCopy._();

  static const title = 'Indexing evidence';
  static const listeningBody =
      'Listening for citable facts in your recording…';
  static const extractingBody = 'Committing citable anchors to your ledger…';
  static const emptyBody =
      'No citable anchors found yet — your moment is still saved locally.';
  static const liveFeedLabel = 'Live fact ledger feed';

  static String completionBanner(int count) {
    final noun = count == 1 ? 'anchor' : 'anchors';
    return 'Saved $count new citable $noun to your permanent Evidence Ledger.';
  }

  static const inspectEvidenceTrail = 'Inspect Evidence Trail';
  static const returnToArchive = 'Return to Archive';
}