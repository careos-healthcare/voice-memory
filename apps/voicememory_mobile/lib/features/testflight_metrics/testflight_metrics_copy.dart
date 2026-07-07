/// Display-only copy for the TestFlight beta metrics dashboard.
abstract final class TestFlightMetricsCopy {
  TestFlightMetricsCopy._();

  static const title = 'TestFlight beta metrics';

  static const subtitle =
      'Track whether users reach the ArchiveMe proof moment.';

  static const localCountsNote =
      'Local device counts only — no transcripts or personal text.';

  static const coreMetricsTitle = 'Revenue readiness funnel';

  static const retentionTitle = 'Retention markers';

  static const firstSave = 'First save';
  static const secondSave = 'Second save';
  static const thirdSave = 'Third save';
  static const firstProofSeen = 'First proof seen';
  static const timelineProofSeen = 'Timeline proof seen';
  static const useful = 'Useful';
  static const tooVague = 'Too vague';
  static const alreadyKnewThis = 'Already knew this';
  static const notRelevant = 'Not relevant';
  static const paywallIntent = 'Paywall intent';

  static const returnedAfterFirstProof = 'Returned after first proof';
  static const skippedThenReturned = 'Skipped then returned';
  static const purchaseCtaTapped = 'Purchase CTA tapped';

  static const statusMissing = 'missing';
  static const statusSeen = 'seen';

  static const List<String> coreMetricLabels = [
    firstSave,
    secondSave,
    thirdSave,
    firstProofSeen,
    timelineProofSeen,
    useful,
    tooVague,
    alreadyKnewThis,
    notRelevant,
    paywallIntent,
  ];

  static const List<String> retentionMetricLabels = [
    returnedAfterFirstProof,
    skippedThenReturned,
    purchaseCtaTapped,
  ];
}
