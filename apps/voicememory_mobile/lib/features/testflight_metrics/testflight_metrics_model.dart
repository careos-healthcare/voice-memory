import 'testflight_metrics_copy.dart';

enum TestFlightMetricId {
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
  returnedAfterFirstProof,
  skippedThenReturned,
  purchaseCtaTapped,
}

class TestFlightMetricRow {
  const TestFlightMetricRow({
    required this.id,
    required this.label,
    required this.seen,
    this.count = 0,
  });

  final TestFlightMetricId id;
  final String label;
  final bool seen;
  final int count;

  String get statusLabel => seen
      ? TestFlightMetricsCopy.statusSeen
      : TestFlightMetricsCopy.statusMissing;

  String get countLabel => count > 0 ? count.toString() : statusLabel;
}

class TestFlightMetricsDashboard {
  const TestFlightMetricsDashboard({
    required this.title,
    required this.subtitle,
    required this.coreMetrics,
    required this.retentionMetrics,
    required this.metricCount,
  });

  final String title;
  final String subtitle;
  final List<TestFlightMetricRow> coreMetrics;
  final List<TestFlightMetricRow> retentionMetrics;
  final int metricCount;
}

/// Local-only inputs for building the dashboard — counts and flags only.
class TestFlightMetricsInput {
  const TestFlightMetricsInput({
    this.firstMomentSaved = 0,
    this.secondMomentSaved = 0,
    this.thirdMomentSaved = 0,
    this.firstProofReached = 0,
    this.confirmedRepeatSeen = 0,
    this.timelineProofSeen = false,
    this.usefulCount = 0,
    this.tooVagueCount = 0,
    this.alreadyKnewCount = 0,
    this.notRelevantCount = 0,
    this.purchaseTapped = 0,
    this.returnedAfterFirstProof = 0,
    this.skippedThenReturned = 0,
    this.sessionPaywallIntent = false,
  });

  final int firstMomentSaved;
  final int secondMomentSaved;
  final int thirdMomentSaved;
  final int firstProofReached;
  final int confirmedRepeatSeen;
  final bool timelineProofSeen;
  final int usefulCount;
  final int tooVagueCount;
  final int alreadyKnewCount;
  final int notRelevantCount;
  final int purchaseTapped;
  final int returnedAfterFirstProof;
  final int skippedThenReturned;
  final bool sessionPaywallIntent;
}
