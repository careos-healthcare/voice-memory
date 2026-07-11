import 'core_metrics_minimum_set_copy.dart';

/// Core metrics minimum set — classify release-beta metrics vs diagnostic noise.
abstract final class CoreMetricsMinimumSet {
  CoreMetricsMinimumSet._();

  static const coreMetricCount = 14;

  static const _paidIntentMetricIds = {
    CoreMetricsMinimumMetricId.firstSave,
    CoreMetricsMinimumMetricId.firstUsefulProofSeen,
    CoreMetricsMinimumMetricId.proofAccepted,
    CoreMetricsMinimumMetricId.proofCorrected,
    CoreMetricsMinimumMetricId.proPromiseSeen,
    CoreMetricsMinimumMetricId.proTapped,
    CoreMetricsMinimumMetricId.purchaseStarted,
    CoreMetricsMinimumMetricId.purchaseCompleted,
    CoreMetricsMinimumMetricId.restoreTapped,
  };

  static final Map<String, CoreMetricsMinimumMetricId> _eventAliases = {
    for (final entry in _metricEventAliases.entries)
      for (final event in entry.value) event: entry.key,
  };

  static const Map<CoreMetricsMinimumMetricId, List<String>> _metricEventAliases =
      {
    CoreMetricsMinimumMetricId.appOpened: [
      'app_opened',
      'invited_app_opened',
    ],
    CoreMetricsMinimumMetricId.firstSave: [
      'first_recording_saved',
      'first_60_first_save_completed',
      'first_save_rescue_saved',
      'first_recording_sample_saved',
    ],
    CoreMetricsMinimumMetricId.secondSave: [
      'second_save',
      'second_recording_saved',
    ],
    CoreMetricsMinimumMetricId.firstUsefulProofSeen: [
      'first_proof_moment_seen',
      'first_proof_seen',
      'first_proof_payoff_seen',
    ],
    CoreMetricsMinimumMetricId.proofAccepted: [
      'beta_proof_feedback_answered',
      'first_proof_truth_answered',
    ],
    CoreMetricsMinimumMetricId.proofCorrected: [
      'correction_memory_saved',
      'transcript_correction_saved',
      'pattern_correction_action_selected',
    ],
    CoreMetricsMinimumMetricId.proPromiseSeen: [
      'value_moment_pro_bridge_seen',
      'pro_evidence_value_seen',
      'pro_continuity_bridge_seen',
      'first_60_pro_bridge_seen',
      'paywall_seen',
    ],
    CoreMetricsMinimumMetricId.proTapped: [
      'value_moment_pro_bridge_tapped',
      'pro_evidence_value_cta_tapped',
      'pro_continuity_bridge_tapped',
      'first_60_pro_bridge_tapped',
      'paywall_purchase_cta_tapped',
    ],
    CoreMetricsMinimumMetricId.purchaseStarted: [
      'purchase_started',
      'invited_purchase_started',
      'subscription_purchase_started',
    ],
    CoreMetricsMinimumMetricId.purchaseCompleted: [
      'purchase_completed',
      'invited_purchase_completed',
      'subscription_purchase_completed',
    ],
    CoreMetricsMinimumMetricId.restoreTapped: [
      'restore_started',
      'paywall_restore_tapped',
    ],
    CoreMetricsMinimumMetricId.restoreSucceeded: [
      'restore_completed',
    ],
    CoreMetricsMinimumMetricId.entitlementActive: [
      'entitlement_active',
      'entitlement_received',
    ],
    CoreMetricsMinimumMetricId.crashOrBlockerReported: [
      'crash_blocker_reported',
      'beta_blocker_reported',
      'beta_feedback_submitted',
    ],
  };

  static CoreMetricsMinimumSetResult build() {
    final metrics = [
      for (final id in CoreMetricsMinimumMetricId.values)
        CoreMetricsMinimumMetricDefinition(
          id: id,
          label: CoreMetricsMinimumSetCopy.labelFor(id),
          canonicalEvent: _metricEventAliases[id]!.first,
          eventAliases: _metricEventAliases[id]!,
          usedForPaidIntentDecision: _paidIntentMetricIds.contains(id),
        ),
    ];

    return CoreMetricsMinimumSetResult(
      headline: CoreMetricsMinimumSetCopy.headline,
      body: CoreMetricsMinimumSetCopy.body,
      coreLine: CoreMetricsMinimumSetCopy.coreLine,
      diagnosticLine: CoreMetricsMinimumSetCopy.diagnosticLine,
      guardrail: CoreMetricsMinimumSetCopy.guardrail,
      metrics: metrics,
    );
  }

  static CoreMetricsMinimumClassification classify(
    String eventName, {
    Map<String, Object>? properties,
  }) {
    final normalized = eventName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return CoreMetricsMinimumClassification.diagnostic(eventName: eventName);
    }

    final propertyMetric = _metricFromProperties(normalized, properties);
    if (propertyMetric != null) {
      return _coreClassification(
        eventName: normalized,
        metricId: propertyMetric,
      );
    }

    final metricId = _eventAliases[normalized];
    if (metricId == null) {
      return CoreMetricsMinimumClassification.diagnostic(eventName: normalized);
    }

    if (metricId == CoreMetricsMinimumMetricId.proofAccepted &&
        !_proofAcceptedProperties(properties)) {
      return CoreMetricsMinimumClassification.diagnostic(eventName: normalized);
    }

    if (metricId == CoreMetricsMinimumMetricId.crashOrBlockerReported &&
        normalized == 'beta_feedback_submitted' &&
        !_crashOrBlockerProperties(properties)) {
      return CoreMetricsMinimumClassification.diagnostic(eventName: normalized);
    }

    return _coreClassification(eventName: normalized, metricId: metricId);
  }

  static bool isCoreBetaEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) =>
      classify(eventName, properties: properties).isCoreBeta;

  static CoreMetricsMinimumMetricId? metricIdFor(
    String eventName, {
    Map<String, Object>? properties,
  }) =>
      classify(eventName, properties: properties).coreMetricId;

  static CoreMetricsMinimumClassification _coreClassification({
    required String eventName,
    required CoreMetricsMinimumMetricId metricId,
  }) =>
      CoreMetricsMinimumClassification(
        eventName: eventName,
        coreMetricId: metricId,
        isCoreBeta: true,
        diagnosticOnly: false,
        notReleaseBlocking: false,
        notUsedForPaidIntentDecision: !_paidIntentMetricIds.contains(metricId),
      );

  static CoreMetricsMinimumMetricId? _metricFromProperties(
    String eventName,
    Map<String, Object>? properties,
  ) {
    if (properties == null) return null;

    if (eventName == 'recording_created') {
      final saveIndex = _readInt(properties['save_index'] ?? properties['entry_count']);
      if (saveIndex == 1) return CoreMetricsMinimumMetricId.firstSave;
      if (saveIndex == 2) return CoreMetricsMinimumMetricId.secondSave;
    }

    return null;
  }

  static bool _proofAcceptedProperties(Map<String, Object>? properties) {
    if (properties == null) return true;
    final feedbackType = _readString(
      properties['feedback_type'] ?? properties['answer'],
    );
    if (feedbackType == null) return true;
    return feedbackType == 'useful' || feedbackType == 'accepted';
  }

  static bool _crashOrBlockerProperties(Map<String, Object>? properties) {
    if (properties == null) return false;
    final optionType = _readString(
      properties['option_type'] ?? properties['feedback_type'],
    );
    return optionType == 'crash' ||
        optionType == 'blocker' ||
        optionType == 'wrong';
  }

  static String? _readString(Object? value) {
    if (value == null) return null;
    final normalized = value.toString().trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class CoreMetricsMinimumClassification {
  const CoreMetricsMinimumClassification({
    required this.eventName,
    required this.coreMetricId,
    required this.isCoreBeta,
    required this.diagnosticOnly,
    required this.notReleaseBlocking,
    required this.notUsedForPaidIntentDecision,
  });

  factory CoreMetricsMinimumClassification.diagnostic({
    required String eventName,
  }) =>
      CoreMetricsMinimumClassification(
        eventName: eventName,
        coreMetricId: null,
        isCoreBeta: false,
        diagnosticOnly: true,
        notReleaseBlocking: true,
        notUsedForPaidIntentDecision: true,
      );

  final String eventName;
  final CoreMetricsMinimumMetricId? coreMetricId;
  final bool isCoreBeta;
  final bool diagnosticOnly;
  final bool notReleaseBlocking;
  final bool notUsedForPaidIntentDecision;
}

class CoreMetricsMinimumMetricDefinition {
  const CoreMetricsMinimumMetricDefinition({
    required this.id,
    required this.label,
    required this.canonicalEvent,
    required this.eventAliases,
    required this.usedForPaidIntentDecision,
  });

  final CoreMetricsMinimumMetricId id;
  final String label;
  final String canonicalEvent;
  final List<String> eventAliases;
  final bool usedForPaidIntentDecision;
}

class CoreMetricsMinimumSetResult {
  const CoreMetricsMinimumSetResult({
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
  final List<CoreMetricsMinimumMetricDefinition> metrics;

  int get coreMetricCount => metrics.length;

  List<CoreMetricsMinimumMetricDefinition> get paidIntentMetrics =>
      metrics.where((metric) => metric.usedForPaidIntentDecision).toList();
}
