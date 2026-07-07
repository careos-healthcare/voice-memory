import '../beta/beta_activation_loop_tracker.dart';
import '../beta_activation/beta_activation_summary_tracker.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../revenue_metrics/revenue_funnel_analytics.dart';
import '../revenue_metrics/revenue_funnel_event.dart';
import 'testflight_metrics_copy.dart';
import 'testflight_metrics_model.dart';

/// Builds a local TestFlight beta metrics dashboard from safe device counters.
abstract final class TestFlightMetricsEngine {
  TestFlightMetricsEngine._();

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static Future<TestFlightMetricsDashboard> build() async {
    final input = await loadInput();
    return buildFromInput(input);
  }

  static Future<TestFlightMetricsInput> loadInput() async {
    await BetaProofFeedbackStore.ensureLoaded();
    final loaded = await BetaActivationSummaryTracker.loadAll();
    final feedbackCounts = _feedbackCountsByType();
    final sessionPaywallIntent = RevenueFunnelAnalytics.recordedEvents.any(
      (record) => record.event == RevenueFunnelEvent.paywallPurchaseCtaTapped,
    );

    return TestFlightMetricsInput(
      firstMomentSaved: loaded.loop.firstMomentSaved,
      secondMomentSaved: loaded.loop.secondMomentSaved,
      thirdMomentSaved: loaded.loop.thirdMomentSaved,
      firstProofReached: loaded.extension.firstProofReached,
      confirmedRepeatSeen: loaded.loop.confirmedRepeatSeen,
      timelineProofSeen: _timelineProofSeen(),
      usefulCount: feedbackCounts[BetaProofFeedbackType.useful] ?? 0,
      tooVagueCount: feedbackCounts[BetaProofFeedbackType.tooVague] ?? 0,
      alreadyKnewCount: feedbackCounts[BetaProofFeedbackType.alreadyKnew] ?? 0,
      notRelevantCount: feedbackCounts[BetaProofFeedbackType.notRelevant] ?? 0,
      purchaseTapped: loaded.loop.purchaseTapped,
      returnedAfterFirstProof: loaded.loop.returnedAfterFirstProof,
      skippedThenReturned: loaded.loop.oneEntryReturnScreenSeen,
      sessionPaywallIntent: sessionPaywallIntent,
    );
  }

  static TestFlightMetricsDashboard buildFromInput(TestFlightMetricsInput input) {
    final coreMetrics = <TestFlightMetricRow>[
      _row(
        id: TestFlightMetricId.firstSave,
        label: TestFlightMetricsCopy.firstSave,
        seen: input.firstMomentSaved > 0,
        count: input.firstMomentSaved,
      ),
      _row(
        id: TestFlightMetricId.secondSave,
        label: TestFlightMetricsCopy.secondSave,
        seen: input.secondMomentSaved > 0,
        count: input.secondMomentSaved,
      ),
      _row(
        id: TestFlightMetricId.thirdSave,
        label: TestFlightMetricsCopy.thirdSave,
        seen: input.thirdMomentSaved > 0,
        count: input.thirdMomentSaved,
      ),
      _row(
        id: TestFlightMetricId.firstProofSeen,
        label: TestFlightMetricsCopy.firstProofSeen,
        seen: input.firstProofReached > 0 || input.confirmedRepeatSeen > 0,
        count: input.firstProofReached > 0
            ? input.firstProofReached
            : input.confirmedRepeatSeen,
      ),
      _row(
        id: TestFlightMetricId.timelineProofSeen,
        label: TestFlightMetricsCopy.timelineProofSeen,
        seen: input.timelineProofSeen,
      ),
      _row(
        id: TestFlightMetricId.useful,
        label: TestFlightMetricsCopy.useful,
        seen: input.usefulCount > 0,
        count: input.usefulCount,
      ),
      _row(
        id: TestFlightMetricId.tooVague,
        label: TestFlightMetricsCopy.tooVague,
        seen: input.tooVagueCount > 0,
        count: input.tooVagueCount,
      ),
      _row(
        id: TestFlightMetricId.alreadyKnewThis,
        label: TestFlightMetricsCopy.alreadyKnewThis,
        seen: input.alreadyKnewCount > 0,
        count: input.alreadyKnewCount,
      ),
      _row(
        id: TestFlightMetricId.notRelevant,
        label: TestFlightMetricsCopy.notRelevant,
        seen: input.notRelevantCount > 0,
        count: input.notRelevantCount,
      ),
      _row(
        id: TestFlightMetricId.paywallIntent,
        label: TestFlightMetricsCopy.paywallIntent,
        seen: input.purchaseTapped > 0 || input.sessionPaywallIntent,
        count: input.purchaseTapped,
      ),
    ];

    final retentionMetrics = <TestFlightMetricRow>[
      _row(
        id: TestFlightMetricId.returnedAfterFirstProof,
        label: TestFlightMetricsCopy.returnedAfterFirstProof,
        seen: input.returnedAfterFirstProof > 0,
        count: input.returnedAfterFirstProof,
      ),
      _row(
        id: TestFlightMetricId.skippedThenReturned,
        label: TestFlightMetricsCopy.skippedThenReturned,
        seen: input.skippedThenReturned > 0,
        count: input.skippedThenReturned,
      ),
      _row(
        id: TestFlightMetricId.purchaseCtaTapped,
        label: TestFlightMetricsCopy.purchaseCtaTapped,
        seen: input.purchaseTapped > 0 || input.sessionPaywallIntent,
        count: input.purchaseTapped,
      ),
    ];

    return TestFlightMetricsDashboard(
      title: TestFlightMetricsCopy.title,
      subtitle: TestFlightMetricsCopy.subtitle,
      coreMetrics: coreMetrics,
      retentionMetrics: retentionMetrics,
      metricCount: coreMetrics.length,
    );
  }

  static TestFlightMetricRow _row({
    required TestFlightMetricId id,
    required String label,
    required bool seen,
    int count = 0,
  }) {
    return TestFlightMetricRow(
      id: id,
      label: label,
      seen: seen,
      count: count,
    );
  }

  static Map<BetaProofFeedbackType, int> _feedbackCountsByType() {
    final counts = <BetaProofFeedbackType, int>{};
    for (final surface in BetaProofFeedbackSurface.values) {
      final record = BetaProofFeedbackStore.recordFor(surface);
      final type = record.feedbackType;
      if (type == null) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  static bool _timelineProofSeen() {
    for (final surface in [
      BetaProofFeedbackSurface.timelineProofMoment,
      BetaProofFeedbackSurface.archiveTimelineSpine,
    ]) {
      if (BetaProofFeedbackStore.recordFor(surface).answered) {
        return true;
      }
    }
    return false;
  }
}
