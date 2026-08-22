import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_beta_reducer_copy.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_minimum_set.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_minimum_set_copy.dart';

/// Core metrics beta reducer — classify beta decision metrics only.
abstract final class CoreMetricsBetaReducer {
  CoreMetricsBetaReducer._();

  static const coreMetricCount = 13;

  static const Set<CoreMetricsBetaMetricId> decisionMetricIds = {
    CoreMetricsBetaMetricId.appOpened,
    CoreMetricsBetaMetricId.firstSave,
    CoreMetricsBetaMetricId.secondSave,
    CoreMetricsBetaMetricId.firstUsefulProofSeen,
    CoreMetricsBetaMetricId.proofAccepted,
    CoreMetricsBetaMetricId.proofCorrected,
    CoreMetricsBetaMetricId.proPromiseSeen,
    CoreMetricsBetaMetricId.proTapped,
    CoreMetricsBetaMetricId.restoreSucceeded,
    CoreMetricsBetaMetricId.entitlementActive,
  };

  static const Set<CoreMetricsBetaMetricId> revenueMetricIds = {
    CoreMetricsBetaMetricId.purchaseStarted,
    CoreMetricsBetaMetricId.purchaseCompleted,
  };

  static const Set<CoreMetricsBetaMetricId> releaseBlockingMetricIds = {
    CoreMetricsBetaMetricId.crashOrBlocker,
  };

  static const Map<String, CoreMetricsBetaMetricId> _activationCounterCoreMap = {
    'appOpened': CoreMetricsBetaMetricId.appOpened,
    'firstMomentSaved': CoreMetricsBetaMetricId.firstSave,
    'secondMomentSaved': CoreMetricsBetaMetricId.secondSave,
  };

  static CoreMetricsBetaReducerResult build() {
    final metrics = [
      for (final id in CoreMetricsBetaMetricId.values)
        CoreMetricsBetaMetricDefinition(
          id: id,
          label: CoreMetricsBetaReducerCopy.labelFor(id),
          bucket: _bucketFor(id),
        ),
    ];

    return CoreMetricsBetaReducerResult(
      headline: CoreMetricsBetaReducerCopy.headline,
      body: CoreMetricsBetaReducerCopy.body,
      coreLine: CoreMetricsBetaReducerCopy.coreLine,
      diagnosticLine: CoreMetricsBetaReducerCopy.diagnosticLine,
      guardrail: CoreMetricsBetaReducerCopy.guardrail,
      metrics: metrics,
    );
  }

  static CoreMetricsBetaClassification classifyEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) {
    final minimum = CoreMetricsMinimumSet.classify(
      eventName,
      properties: properties,
    );
    final betaMetricId = _betaMetricFromMinimum(minimum.coreMetricId);
    if (betaMetricId == null) {
      return CoreMetricsBetaClassification.diagnostic(
        eventName: minimum.eventName,
      );
    }

    return _coreClassification(betaMetricId, eventName: minimum.eventName);
  }

  static CoreMetricsBetaClassification classifyActivationCounter(
    String counterField,
  ) {
    final normalized = counterField.trim();
    final betaMetricId = _activationCounterCoreMap[normalized];
    if (betaMetricId == null) {
      return CoreMetricsBetaClassification.diagnostic(eventName: normalized);
    }

    return _coreClassification(betaMetricId, eventName: normalized);
  }

  static CoreMetricsBetaClassification classifyMetric(
    CoreMetricsBetaMetricId metricId,
  ) => _coreClassification(metricId, eventName: metricId.name);

  static bool isBetaDecisionEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) => !classifyEvent(eventName, properties: properties).notDecisionMetric;

  static bool detectMinimumClassifierPreserved(String minimumSetSource) =>
      minimumSetSource.contains(
        'static CoreMetricsMinimumClassification classify',
      );

  static CoreMetricsBetaBucket _bucketFor(CoreMetricsBetaMetricId id) {
    if (revenueMetricIds.contains(id)) {
      return CoreMetricsBetaBucket.revenueMetric;
    }
    if (releaseBlockingMetricIds.contains(id)) {
      return CoreMetricsBetaBucket.releaseBlocking;
    }
    return CoreMetricsBetaBucket.decisionMetric;
  }

  static CoreMetricsBetaMetricId? _betaMetricFromMinimum(
    CoreMetricsMinimumMetricId? minimumId,
  ) {
    if (minimumId == null) return null;
    return switch (minimumId) {
      CoreMetricsMinimumMetricId.appOpened => CoreMetricsBetaMetricId.appOpened,
      CoreMetricsMinimumMetricId.firstSave => CoreMetricsBetaMetricId.firstSave,
      CoreMetricsMinimumMetricId.secondSave =>
        CoreMetricsBetaMetricId.secondSave,
      CoreMetricsMinimumMetricId.firstUsefulProofSeen =>
        CoreMetricsBetaMetricId.firstUsefulProofSeen,
      CoreMetricsMinimumMetricId.proofAccepted =>
        CoreMetricsBetaMetricId.proofAccepted,
      CoreMetricsMinimumMetricId.proofCorrected =>
        CoreMetricsBetaMetricId.proofCorrected,
      CoreMetricsMinimumMetricId.proPromiseSeen =>
        CoreMetricsBetaMetricId.proPromiseSeen,
      CoreMetricsMinimumMetricId.proTapped => CoreMetricsBetaMetricId.proTapped,
      CoreMetricsMinimumMetricId.purchaseStarted =>
        CoreMetricsBetaMetricId.purchaseStarted,
      CoreMetricsMinimumMetricId.purchaseCompleted =>
        CoreMetricsBetaMetricId.purchaseCompleted,
      CoreMetricsMinimumMetricId.restoreSucceeded =>
        CoreMetricsBetaMetricId.restoreSucceeded,
      CoreMetricsMinimumMetricId.entitlementActive =>
        CoreMetricsBetaMetricId.entitlementActive,
      CoreMetricsMinimumMetricId.crashOrBlockerReported =>
        CoreMetricsBetaMetricId.crashOrBlocker,
      CoreMetricsMinimumMetricId.restoreTapped => null,
    };
  }

  static CoreMetricsBetaClassification _coreClassification(
    CoreMetricsBetaMetricId metricId, {
    required String eventName,
  }) {
    final bucket = _bucketFor(metricId);
    return CoreMetricsBetaClassification(
      eventName: eventName,
      coreMetricId: metricId,
      bucket: bucket,
      diagnosticOnly: false,
      notDecisionMetric: bucket != CoreMetricsBetaBucket.decisionMetric,
      notReleaseBlocking: bucket != CoreMetricsBetaBucket.releaseBlocking,
    );
  }
}

class CoreMetricsBetaClassification {
  const CoreMetricsBetaClassification({
    required this.eventName,
    required this.coreMetricId,
    required this.bucket,
    required this.diagnosticOnly,
    required this.notDecisionMetric,
    required this.notReleaseBlocking,
  });

  factory CoreMetricsBetaClassification.diagnostic({
    required String eventName,
  }) => CoreMetricsBetaClassification(
    eventName: eventName,
    coreMetricId: null,
    bucket: CoreMetricsBetaBucket.diagnosticOnly,
    diagnosticOnly: true,
    notDecisionMetric: true,
    notReleaseBlocking: true,
  );

  final String eventName;
  final CoreMetricsBetaMetricId? coreMetricId;
  final CoreMetricsBetaBucket bucket;
  final bool diagnosticOnly;
  final bool notDecisionMetric;
  final bool notReleaseBlocking;

  bool get isDecisionMetric => bucket == CoreMetricsBetaBucket.decisionMetric;
  bool get isRevenueMetric => bucket == CoreMetricsBetaBucket.revenueMetric;
  bool get isReleaseBlocking => bucket == CoreMetricsBetaBucket.releaseBlocking;
}

class CoreMetricsBetaMetricDefinition {
  const CoreMetricsBetaMetricDefinition({
    required this.id,
    required this.label,
    required this.bucket,
  });

  final CoreMetricsBetaMetricId id;
  final String label;
  final CoreMetricsBetaBucket bucket;
}

class CoreMetricsBetaReducerResult {
  const CoreMetricsBetaReducerResult({
    required this.headline,
    required this.body,
    required this.coreLine,
    required this.diagnosticLine,
    required this.guardrail,
    required this.metrics,
  });

  final String headline;
  final String body;
  final String coreLine;
  final String diagnosticLine;
  final String guardrail;
  final List<CoreMetricsBetaMetricDefinition> metrics;

  int get coreMetricCount => metrics.length;

  List<CoreMetricsBetaMetricDefinition> get decisionMetrics => metrics
      .where((metric) => metric.bucket == CoreMetricsBetaBucket.decisionMetric)
      .toList();

  List<CoreMetricsBetaMetricDefinition> get revenueMetrics => metrics
      .where((metric) => metric.bucket == CoreMetricsBetaBucket.revenueMetric)
      .toList();

  List<CoreMetricsBetaMetricDefinition> get releaseBlockingMetrics => metrics
      .where((metric) => metric.bucket == CoreMetricsBetaBucket.releaseBlocking)
      .toList();
}