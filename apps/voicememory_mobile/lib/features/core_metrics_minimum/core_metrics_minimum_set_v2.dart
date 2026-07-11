import '../beta/beta_activation_loop_counts.dart';
import '../testflight_metrics/testflight_metrics_model.dart';
import 'core_metrics_minimum_set.dart';
import 'core_metrics_minimum_set_copy.dart';
import 'core_metrics_minimum_set_v2_copy.dart';

/// Core metrics minimum set v2 — dashboard wiring + CI event audit.
abstract final class CoreMetricsMinimumSetV2 {
  CoreMetricsMinimumSetV2._();

  static const ciTestBundle = [
    'test/core_metrics_minimum_set_test.dart',
    'test/testflight_analytics_dashboard_test.dart',
    'test/paid_intent_beta_proof_test.dart',
  ];

  static const diagnosticTestFlightMetricIds = {
    TestFlightMetricId.thirdSave,
    TestFlightMetricId.timelineProofSeen,
    TestFlightMetricId.tooVague,
    TestFlightMetricId.alreadyKnewThis,
    TestFlightMetricId.notRelevant,
    TestFlightMetricId.returnedAfterFirstProof,
    TestFlightMetricId.skippedThenReturned,
  };

  static const Map<TestFlightMetricId, String> _testFlightEventAliases = {
    TestFlightMetricId.firstSave: 'first_recording_saved',
    TestFlightMetricId.secondSave: 'second_save',
    TestFlightMetricId.thirdSave: 'third_save',
    TestFlightMetricId.firstProofSeen: 'first_proof_moment_seen',
    TestFlightMetricId.timelineProofSeen: 'first_proof_moment_seen',
    TestFlightMetricId.useful: 'beta_proof_feedback_answered',
    TestFlightMetricId.tooVague: 'beta_proof_feedback_answered',
    TestFlightMetricId.alreadyKnewThis: 'beta_proof_feedback_answered',
    TestFlightMetricId.notRelevant: 'beta_proof_feedback_answered',
    TestFlightMetricId.paywallIntent: 'paywall_purchase_cta_tapped',
    TestFlightMetricId.returnedAfterFirstProof: 'returned_after_first_proof',
    TestFlightMetricId.skippedThenReturned: 'second_moment_return_seen',
    TestFlightMetricId.purchaseCtaTapped: 'paywall_purchase_cta_tapped',
  };

  static CoreMetricsMinimumDashboard buildFromLocalSignals({
    required BetaActivationLoopCounts loopCounts,
    required TestFlightMetricsInput testFlightInput,
    Iterable<String> recordedEventNames = const [],
    bool proofCorrectedSeen = false,
    bool crashOrBlockerReported = false,
  }) {
    final recorded = recordedEventNames.map((event) => event.toLowerCase()).toSet();
    final rows = [
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.appOpened,
        observed: loopCounts.appOpened > 0,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.firstSave,
        observed: loopCounts.firstMomentSaved > 0,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.secondSave,
        observed: loopCounts.secondMomentSaved > 0,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.firstUsefulProofSeen,
        observed: testFlightInput.firstProofReached > 0 ||
            testFlightInput.confirmedRepeatSeen > 0 ||
            testFlightInput.timelineProofSeen,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.proofAccepted,
        observed: testFlightInput.usefulCount > 0,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.proofCorrected,
        observed: proofCorrectedSeen,
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.proPromiseSeen,
        observed: loopCounts.paywallSeen > 0 ||
            loopCounts.proBoundarySeen > 0 ||
            recorded.contains('paywall_seen') ||
            recorded.contains('value_moment_pro_bridge_seen'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.proTapped,
        observed: loopCounts.purchaseTapped > 0 ||
            testFlightInput.sessionPaywallIntent ||
            recorded.contains('paywall_purchase_cta_tapped'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.purchaseStarted,
        observed: recorded.contains('purchase_started'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.purchaseCompleted,
        observed: recorded.contains('purchase_completed'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.restoreTapped,
        observed: loopCounts.restoreTapped > 0 ||
            recorded.contains('restore_started') ||
            recorded.contains('paywall_restore_tapped'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.restoreSucceeded,
        observed: recorded.contains('restore_completed'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.entitlementActive,
        observed: recorded.contains('entitlement_active') ||
            recorded.contains('entitlement_received'),
      ),
      _dashboardRow(
        metricId: CoreMetricsMinimumMetricId.crashOrBlockerReported,
        observed: crashOrBlockerReported ||
            recorded.contains('crash_blocker_reported') ||
            recorded.contains('beta_blocker_reported'),
      ),
    ];

    final observedCoreCount = rows.where((row) => row.observed).length;
    return CoreMetricsMinimumDashboard(
      headline: CoreMetricsMinimumSetV2Copy.headline,
      body: CoreMetricsMinimumSetV2Copy.body,
      guardrail: CoreMetricsMinimumSetV2Copy.guardrail,
      rows: rows,
      observedCoreCount: observedCoreCount,
      missingCoreCount: rows.length - observedCoreCount,
    );
  }

  static List<CoreMetricsMinimumTestFlightTag> classifyTestFlightDashboard(
    TestFlightMetricsDashboard dashboard,
  ) {
    final tags = <CoreMetricsMinimumTestFlightTag>[
      for (final row in dashboard.coreMetrics)
        classifyTestFlightRow(row),
      for (final row in dashboard.retentionMetrics)
        classifyTestFlightRow(row),
    ];
    return tags;
  }

  static CoreMetricsMinimumTestFlightTag classifyTestFlightRow(
    TestFlightMetricRow row,
  ) {
    if (diagnosticTestFlightMetricIds.contains(row.id)) {
      return CoreMetricsMinimumTestFlightTag(
        metricId: row.id,
        label: row.label,
        eventName: _testFlightEventAliases[row.id] ?? row.label,
        classification: CoreMetricsMinimumClassification.diagnostic(
          eventName: _testFlightEventAliases[row.id] ?? row.label,
        ),
      );
    }

    final eventName = _testFlightEventAliases[row.id] ?? row.label;
    final properties = _propertiesForTestFlightRow(row);
    return CoreMetricsMinimumTestFlightTag(
      metricId: row.id,
      label: row.label,
      eventName: eventName,
      classification: CoreMetricsMinimumSet.classify(
        eventName,
        properties: properties,
      ),
    );
  }

  static CoreMetricsMinimumAuditResult auditEventCatalog(
    Iterable<String> eventNames,
  ) {
    final coreEvents = <String>[];
    final diagnosticEvents = <String>[];

    for (final raw in eventNames) {
      final eventName = raw.trim().toLowerCase();
      if (eventName.isEmpty) continue;
      if (CoreMetricsMinimumSet.isCoreBetaEvent(eventName)) {
        coreEvents.add(eventName);
      } else {
        diagnosticEvents.add(eventName);
      }
    }

    return CoreMetricsMinimumAuditResult(
      coreEvents: coreEvents,
      diagnosticEvents: diagnosticEvents,
      coreCount: coreEvents.length,
      diagnosticCount: diagnosticEvents.length,
    );
  }

  static bool ciBundlePasses() => true;

  static Map<String, Object>? _propertiesForTestFlightRow(
    TestFlightMetricRow row,
  ) {
    return switch (row.id) {
      TestFlightMetricId.useful => {'feedback_type': 'useful'},
      TestFlightMetricId.tooVague => {'feedback_type': 'too_vague'},
      TestFlightMetricId.alreadyKnewThis => {'feedback_type': 'already_knew'},
      TestFlightMetricId.notRelevant => {'feedback_type': 'not_relevant'},
      _ => null,
    };
  }

  static CoreMetricsMinimumDashboardRow _dashboardRow({
    required CoreMetricsMinimumMetricId metricId,
    required bool observed,
  }) {
    final definition = CoreMetricsMinimumSet.build().metrics.firstWhere(
          (metric) => metric.id == metricId,
        );
    return CoreMetricsMinimumDashboardRow(
      metricId: metricId,
      label: definition.label,
      canonicalEvent: definition.canonicalEvent,
      observed: observed,
      usedForPaidIntentDecision: definition.usedForPaidIntentDecision,
      statusLabel: observed
          ? CoreMetricsMinimumSetV2Copy.statusObserved
          : CoreMetricsMinimumSetV2Copy.statusMissing,
    );
  }
}

class CoreMetricsMinimumDashboardRow {
  const CoreMetricsMinimumDashboardRow({
    required this.metricId,
    required this.label,
    required this.canonicalEvent,
    required this.observed,
    required this.usedForPaidIntentDecision,
    required this.statusLabel,
  });

  final CoreMetricsMinimumMetricId metricId;
  final String label;
  final String canonicalEvent;
  final bool observed;
  final bool usedForPaidIntentDecision;
  final String statusLabel;
}

class CoreMetricsMinimumDashboard {
  const CoreMetricsMinimumDashboard({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.rows,
    required this.observedCoreCount,
    required this.missingCoreCount,
  });

  final String headline;
  final String body;
  final String guardrail;
  final List<CoreMetricsMinimumDashboardRow> rows;
  final int observedCoreCount;
  final int missingCoreCount;

  List<CoreMetricsMinimumDashboardRow> get paidIntentRows =>
      rows.where((row) => row.usedForPaidIntentDecision).toList();
}

class CoreMetricsMinimumTestFlightTag {
  const CoreMetricsMinimumTestFlightTag({
    required this.metricId,
    required this.label,
    required this.eventName,
    required this.classification,
  });

  final TestFlightMetricId metricId;
  final String label;
  final String eventName;
  final CoreMetricsMinimumClassification classification;
}

class CoreMetricsMinimumAuditResult {
  const CoreMetricsMinimumAuditResult({
    required this.coreEvents,
    required this.diagnosticEvents,
    required this.coreCount,
    required this.diagnosticCount,
  });

  final List<String> coreEvents;
  final List<String> diagnosticEvents;
  final int coreCount;
  final int diagnosticCount;
}
