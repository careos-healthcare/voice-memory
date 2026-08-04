import 'dart:convert';

import '../../models/journal_entry.dart';
import '../../services/analytics/analytics_catalog.dart';
import '../explainable_conclusion/explainable_conclusion.dart';

/// A step in the V1 validation funnel, named by its catalogued event id.
enum ProductFunnelStep {
  firstCaptureStarted,
  firstCaptureSaved,
  transcriptReviewed,
  firstValidObservationDelivered,
  interpretationFeedbackSubmitted,
  secondEntrySaved,
  firstValidComparisonDelivered,
  changesOpened,
  changeThreadOpened,
  weeklyReviewOpened,
  paywallShownAfterValue,
  purchaseStarted,
  purchaseCompleted,
  restoreCompleted,
  exportCompleted,
}

extension ProductFunnelStepEventId on ProductFunnelStep {
  String get eventId => switch (this) {
    ProductFunnelStep.firstCaptureStarted => 'first_capture_started',
    ProductFunnelStep.firstCaptureSaved => 'first_capture_saved',
    ProductFunnelStep.transcriptReviewed => 'transcript_reviewed',
    ProductFunnelStep.firstValidObservationDelivered =>
      'first_valid_observation_delivered',
    ProductFunnelStep.interpretationFeedbackSubmitted =>
      'interpretation_feedback_submitted',
    ProductFunnelStep.secondEntrySaved => 'second_entry_saved',
    ProductFunnelStep.firstValidComparisonDelivered =>
      'first_valid_comparison_delivered',
    ProductFunnelStep.changesOpened => 'changes_opened',
    ProductFunnelStep.changeThreadOpened => 'change_thread_opened',
    ProductFunnelStep.weeklyReviewOpened => 'weekly_review_opened',
    ProductFunnelStep.paywallShownAfterValue => 'paywall_shown_after_value',
    ProductFunnelStep.purchaseStarted => 'purchase_started',
    ProductFunnelStep.purchaseCompleted => 'purchase_completed',
    ProductFunnelStep.restoreCompleted => 'restore_completed',
    ProductFunnelStep.exportCompleted => 'export_completed',
  };
}

/// Mirrors `AnalyticsCatalog.feedbackChoices`.
enum CohortFeedbackChoice { accurate, wrongAngle, tooGeneric, hide }

/// Mirrors `AnalyticsCatalog.accessDecisions`.
enum CohortAccessDecision {
  allowed,
  deniedProRequired,
  deniedQuota,
  deniedNotEligible,
}

/// Mirrors `AnalyticsCatalog.subscriptionStates`.
enum CohortSubscriptionState { free, proActive, proExpired, proGrace }

/// One participant's structural summary.
///
/// [archive] is the only field that carries journal substance, and nothing read
/// from it leaves this file as text: entries are counted, never quoted.
final class CohortParticipantSnapshot {
  const CohortParticipantSnapshot({
    this.archive = const [],
    this.subscriptionState = CohortSubscriptionState.free,
    this.reachedSteps = const {},
    this.changesOpenCount = 0,
    this.comparisonCount = 0,
    this.interpretationFeedback,
    this.paywallAccessDecision,
    this.firstObservationLatency,
    this.secondEntryDelay,
    this.firstComparisonDelay,
    this.secondEntryInSameSession = false,
  });

  final List<SavedMoment> archive;
  final CohortSubscriptionState subscriptionState;
  final Set<ProductFunnelStep> reachedSteps;
  final int changesOpenCount;
  final int comparisonCount;
  final CohortFeedbackChoice? interpretationFeedback;
  final CohortAccessDecision? paywallAccessDecision;

  /// How long the first observation took to appear after the first save.
  final Duration? firstObservationLatency;

  /// How long after the first save the second entry arrived.
  final Duration? secondEntryDelay;

  /// How long after the second entry the first comparison arrived.
  final Duration? firstComparisonDelay;

  /// Set when the second entry happened before the app left the foreground.
  final bool secondEntryInSameSession;
}

/// Cohort-level analysis data with no journal substance in it.
///
/// Every value is a catalogued band, flag, or event id. Nothing derived from
/// user text — transcripts, quotes, topics, thread labels, markers, correction
/// notes, prompts, generated questions, conclusion wording, inferred sensitive
/// categories — is read into the payload, and [validate] rejects the whole
/// export if a value ever appears that the analytics catalog would not accept.
final class ProductMetricsCohortExport {
  ProductMetricsCohortExport._(this._payload);

  static const String schemaName = 'product_metrics_cohort_export';
  static const int schemaVersion = 1;

  final Map<String, Object> _payload;

  Map<String, Object> toJson() => _payload;

  String toJsonString() => jsonEncode(_payload);

  static ProductMetricsCohortExport build({
    required Iterable<CohortParticipantSnapshot> participants,
    bool realUserCohort = false,
  }) {
    final cohort = participants.toList(growable: false);
    final payload = <String, Object>{
      'schema': schemaName,
      'schema_version': schemaVersion,
      'no_user_text': '1',
      'real_user_cohort': realUserCohort ? '1' : '0',
      'participant_count_bucket': AnalyticsCatalog.countBucket(cohort.length),
      'participants': [
        for (final participant in cohort) _participantRow(participant),
      ],
      'funnel_steps': [
        for (final step in ProductFunnelStep.values)
          if (_countWhere(cohort, (p) => p.reachedSteps.contains(step))
              case final int reached when reached > 0)
            {
              'event': step.eventId,
              'participant_count_bucket': AnalyticsCatalog.countBucket(reached),
            },
      ],
      'first_observation_latency': _distribution(
        bands: AnalyticsCatalog.performanceDurationBands,
        key: 'performance_duration_band',
        cohort: cohort,
        band: (p) => p.firstObservationLatency == null
            ? null
            : AnalyticsCatalog.durationBand(p.firstObservationLatency!),
      ),
      'second_entry_latency': _distribution(
        bands: AnalyticsCatalog.timeBands,
        key: 'time_band',
        cohort: cohort,
        band: (p) => _timeBand(
          p.secondEntryDelay,
          sameSession: p.secondEntryInSameSession,
        ),
      ),
      'first_comparison_latency': _distribution(
        bands: AnalyticsCatalog.timeBands,
        key: 'time_band',
        cohort: cohort,
        band: (p) => _timeBand(p.firstComparisonDelay),
      ),
      'interpretation_feedback': _distribution(
        bands: AnalyticsCatalog.feedbackChoices,
        key: 'feedback_choice',
        cohort: cohort,
        band: (p) => p.interpretationFeedback?.token,
      ),
      'paywall_access': _distribution(
        bands: AnalyticsCatalog.accessDecisions,
        key: 'access_decision',
        cohort: cohort,
        band: (p) => p.paywallAccessDecision?.token,
      ),
      'subscription_mix': _distribution(
        bands: AnalyticsCatalog.subscriptionStates,
        key: 'subscription_state',
        cohort: cohort,
        band: (p) => p.subscriptionState.token,
      ),
    };
    return ProductMetricsCohortExport._(validate(payload));
  }

  static Map<String, Object> _participantRow(
    CohortParticipantSnapshot participant,
  ) {
    final entries =
        participant.archive
            .where((entry) => !entry.isDeleted)
            .toList(growable: false)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final conclusions = [
      for (final entry in entries)
        if (entry.reflection.explainableConclusion != null)
          entry.reflection.explainableConclusion!,
    ];
    final withSupportingEvidence = conclusions
        .where((conclusion) => _supportingSources(conclusion) >= 1)
        .length;
    final strongest = conclusions.map(_supportingSources).fold(0, _max);
    return {
      if (entries.isNotEmpty) 'source_type': entries.first.source.token,
      'subscription_state': participant.subscriptionState.token,
      'entry_count_bucket': AnalyticsCatalog.countBucket(entries.length),
      'reviewed_entry_count_bucket': AnalyticsCatalog.countBucket(
        entries.where((entry) => entry.textEdits.isNotEmpty).length,
      ),
      'reflection_count_bucket': AnalyticsCatalog.countBucket(
        conclusions.length,
      ),
      'evidence_count_band': AnalyticsCatalog.countBucket(
        withSupportingEvidence,
      ),
      'change_count_bucket': AnalyticsCatalog.countBucket(
        participant.comparisonCount,
      ),
      'changes_open_count_bucket': AnalyticsCatalog.countBucket(
        participant.changesOpenCount,
      ),
      'has_first_proof': withSupportingEvidence > 0 ? '1' : '0',
      'has_change': participant.comparisonCount > 0 ? '1' : '0',
      'has_strong_evidence': strongest >= 2 ? '1' : '0',
    };
  }

  static List<Map<String, Object>> _distribution({
    required Set<String> bands,
    required String key,
    required List<CohortParticipantSnapshot> cohort,
    required String? Function(CohortParticipantSnapshot) band,
  }) => [
    for (final value in bands)
      if (_countWhere(cohort, (p) => band(p) == value) case final int count
          when count > 0)
        {
          key: value,
          'participant_count_bucket': AnalyticsCatalog.countBucket(count),
        },
  ];

  static int _countWhere(
    List<CohortParticipantSnapshot> cohort,
    bool Function(CohortParticipantSnapshot) test,
  ) => cohort.where(test).length;

  static int _supportingSources(ExplainableConclusion conclusion) => conclusion
      .evidence
      .where((item) => item.role == TranscriptEvidenceRole.supporting)
      .map((item) => item.entryId)
      .toSet()
      .length;

  static int _max(int a, int b) => a > b ? a : b;

  static String? _timeBand(Duration? value, {bool sameSession = false}) {
    if (value == null) return null;
    if (sameSession) return 'same_session';
    if (value <= const Duration(hours: 24)) return 'within_24h';
    if (value <= const Duration(hours: 72)) return 'within_72h';
    if (value <= const Duration(days: 7)) return 'within_7d';
    return 'over_7d';
  }

  /// Structural container and metadata keys.
  ///
  /// They describe the shape of the export, never a person. Any other key must
  /// be a catalogued analytics property or follow the catalog's bucket-key
  /// grammar.
  static const Set<String> _structuralKeys = {
    'schema',
    'schema_version',
    'no_user_text',
    'real_user_cohort',
    'participants',
    'funnel_steps',
    'first_observation_latency',
    'second_entry_latency',
    'first_comparison_latency',
    'interpretation_feedback',
    'paywall_access',
    'subscription_mix',
    'event',
  };

  /// The single place the no-substance guarantee is enforced.
  ///
  /// Mirrors the final provider guard in `ProductAnalytics`: even if a future
  /// edit reads something textual out of the archive, the export fails loudly
  /// instead of shipping it.
  static Map<String, Object> validate(Map<String, Object> payload) {
    final out = <String, Object>{};
    payload.forEach((key, value) {
      _checkKey(key);
      out[key] = _checkValue(key, value);
    });
    return Map.unmodifiable(out);
  }

  static void _checkKey(String key) {
    if (AnalyticsCatalog.isSensitiveKey(key)) {
      throw StateError('Cohort export key "$key" is sensitive.');
    }
    // A registered analytics property has already been reviewed by the catalog.
    if (AnalyticsCatalog.propertySpecs.containsKey(key)) return;
    // Anything else is a name this file invented, so it also has to clear the
    // catalog's content-marker grammar.
    if (!AnalyticsCatalog.isSafeToken(key)) {
      throw StateError('Cohort export key "$key" is not a safe token.');
    }
    if (_structuralKeys.contains(key)) return;
    if (key.endsWith('_count_bucket')) return;
    throw StateError('Cohort export key "$key" is not catalogued.');
  }

  static Object _checkValue(String key, Object value) {
    if (value is Map<String, Object>) return validate(value);
    if (value is List) {
      return List<Object>.unmodifiable([
        for (final item in value)
          if (item is Map<String, Object>)
            validate(item)
          else if (item is Object)
            _checkValue(key, item)
          else
            throw StateError('Cohort export list "$key" holds a null.'),
      ]);
    }
    if (value is int) {
      if (key == 'schema_version') return value;
      throw StateError('Cohort export value for "$key" is an unbanded number.');
    }
    if (value is! String) {
      throw StateError('Cohort export value for "$key" is not a safe scalar.');
    }
    if (key == 'schema') {
      if (value != schemaName) {
        throw StateError('Cohort export declares an unknown schema.');
      }
      return value;
    }
    if (key == 'event') {
      if (AnalyticsCatalog.activationEvent(value) == null) {
        throw StateError('Cohort export names uncatalogued event "$value".');
      }
      return value;
    }
    if (key.endsWith('_count_bucket')) {
      return _requireMember(key, value, AnalyticsCatalog.countBuckets);
    }
    final spec = AnalyticsCatalog.propertySpecs[key];
    if (spec?.allowedValues != null) {
      return _requireMember(key, value, spec!.allowedValues!);
    }
    if (_structuralKeys.contains(key)) {
      // A structural field carries a flag, never a description.
      return _requireMember(key, value, AnalyticsCatalog.flagValues);
    }
    // What is left is a catalogued token property such as `source_type`, held
    // to the same grammar the analytics guard applies.
    if (!AnalyticsCatalog.isSafeToken(value)) {
      throw StateError('Cohort export value for "$key" is free text.');
    }
    return value;
  }

  static String _requireMember(String key, String value, Set<String> allowed) {
    if (!allowed.contains(value)) {
      throw StateError('Cohort export value for "$key" is uncatalogued.');
    }
    return value;
  }
}

extension on SavedMomentSource {
  String get token => switch (this) {
    SavedMomentSource.voice => 'voice',
    SavedMomentSource.typed => 'typed',
    SavedMomentSource.imported => 'imported',
    SavedMomentSource.migrated => 'migrated',
  };
}

extension on CohortFeedbackChoice {
  String get token => switch (this) {
    CohortFeedbackChoice.accurate => 'accurate',
    CohortFeedbackChoice.wrongAngle => 'wrong_angle',
    CohortFeedbackChoice.tooGeneric => 'too_generic',
    CohortFeedbackChoice.hide => 'hide',
  };
}

extension on CohortAccessDecision {
  String get token => switch (this) {
    CohortAccessDecision.allowed => 'allowed',
    CohortAccessDecision.deniedProRequired => 'denied_pro_required',
    CohortAccessDecision.deniedQuota => 'denied_quota',
    CohortAccessDecision.deniedNotEligible => 'denied_not_eligible',
  };
}

extension on CohortSubscriptionState {
  String get token => switch (this) {
    CohortSubscriptionState.free => 'free',
    CohortSubscriptionState.proActive => 'pro_active',
    CohortSubscriptionState.proExpired => 'pro_expired',
    CohortSubscriptionState.proGrace => 'pro_grace',
  };
}
