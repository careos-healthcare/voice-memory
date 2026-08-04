import 'dart:collection';

/// A catalogued analytics event identifier.
///
/// The private constructor prevents provider payloads from being assembled
/// with an unchecked event name outside this catalog.
final class AnalyticsEventId {
  const AnalyticsEventId._(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AnalyticsValueKind { flag, bucket, token }

enum V1AnalyticsEvent {
  startHereShown,
  startHereSelected,
  postSaveObservationShown,
  postSaveNoConclusion,
  auditableConclusionShown,
  evidenceReceiptOpened,
  exactSourceOpened,
  interpretationFeedbackSubmitted,
  interpretationCorrected,
  conclusionSuppressed,
  earlyComparisonShown,
  reliableChangeDisplayed,
  changesViewed,
  archiveSearchUsed,
  insightNotDisplayedLowEvidence,
  purchaseStarted,
  purchaseCompleted,
  playbackStarted,
  playbackCompleted,
}

/// Privacy-reviewed structural operations. These values describe that a
/// lifecycle boundary was crossed, never which archive, entry, file, person,
/// or provider was involved.
enum OperationalAnalyticsEvent {
  originalSaveStarted,
  originalSaveCompleted,
  originalSaveFailed,
  transcriptionStarted,
  transcriptionCompleted,
  transcriptionFailed,
  interpretationStarted,
  interpretationCompleted,
  interpretationSuppressed,
  interpretationFailed,
  retryScheduled,
  retryStarted,
  retryCompleted,
  retryExhausted,
  vaultWriteStarted,
  vaultWriteCompleted,
  vaultWriteFailed,
  syncStarted,
  syncCompleted,
  syncFailed,
  recoveryStarted,
  recoveryCompleted,
  recoveryFailed,
  purchaseStarted,
  purchaseCompleted,
  purchaseFailed,
  restoreCompleted,
  restoreFailed,
  deletionStarted,
  deletionCompleted,
  deletionFailed,
  exportStarted,
  exportCompleted,
  exportFailed,
}

enum CatalogPricingValidationEvent {
  seen,
  valueStateSelected,
  reasonSelected,
  ctaTapped,
}

enum CatalogPricingValueState {
  monthlyStorePlan,
  annualStorePlan,
  needsMoreValue,
  wouldNotSubscribe,
}

enum CatalogPricingReason {
  moreProofOverTime,
  betterCorrections,
  clearerTimeline,
  lowerPrice,
}

final class AnalyticsPropertySpec {
  const AnalyticsPropertySpec(this.kind, {this.allowedValues});

  final AnalyticsValueKind kind;
  final Set<String>? allowedValues;
}

/// Single machine-readable contract shared by every product analytics path.
///
/// This catalog intentionally describes metadata, never journal/content
/// concepts. Raw ids, timestamps, products, titles, prompts, themes, topics,
/// hashes, account identifiers, and free text are not catalogued.
abstract final class AnalyticsCatalog {
  static AnalyticsEventId v1Event(
    V1AnalyticsEvent event,
  ) => AnalyticsEventId._(switch (event) {
    V1AnalyticsEvent.startHereShown => 'start_here_shown',
    V1AnalyticsEvent.startHereSelected => 'start_here_selected',
    V1AnalyticsEvent.postSaveObservationShown => 'post_save_observation_shown',
    V1AnalyticsEvent.postSaveNoConclusion => 'post_save_no_conclusion',
    V1AnalyticsEvent.auditableConclusionShown => 'auditable_conclusion_shown',
    V1AnalyticsEvent.evidenceReceiptOpened => 'evidence_receipt_opened',
    V1AnalyticsEvent.exactSourceOpened => 'exact_source_opened',
    V1AnalyticsEvent.interpretationFeedbackSubmitted =>
      'interpretation_feedback_submitted',
    V1AnalyticsEvent.interpretationCorrected => 'interpretation_corrected',
    V1AnalyticsEvent.conclusionSuppressed => 'conclusion_suppressed',
    V1AnalyticsEvent.earlyComparisonShown => 'early_comparison_shown',
    V1AnalyticsEvent.reliableChangeDisplayed => 'reliable_change_displayed',
    V1AnalyticsEvent.changesViewed => 'changes_viewed',
    V1AnalyticsEvent.archiveSearchUsed => 'archive_search_used',
    V1AnalyticsEvent.insightNotDisplayedLowEvidence =>
      'insight_not_displayed_low_evidence',
    V1AnalyticsEvent.purchaseStarted => 'purchase_started',
    V1AnalyticsEvent.purchaseCompleted => 'purchase_completed',
    V1AnalyticsEvent.playbackStarted => 'playback_started',
    V1AnalyticsEvent.playbackCompleted => 'playback_completed',
  });

  static AnalyticsEventId operationalEvent(
    OperationalAnalyticsEvent event,
  ) => AnalyticsEventId._(switch (event) {
    OperationalAnalyticsEvent.originalSaveStarted => 'original_save_started',
    OperationalAnalyticsEvent.originalSaveCompleted =>
      'original_save_completed',
    OperationalAnalyticsEvent.originalSaveFailed => 'original_save_failed',
    OperationalAnalyticsEvent.transcriptionStarted => 'transcription_started',
    OperationalAnalyticsEvent.transcriptionCompleted =>
      'transcription_completed',
    OperationalAnalyticsEvent.transcriptionFailed => 'transcription_failed',
    OperationalAnalyticsEvent.interpretationStarted => 'interpretation_started',
    OperationalAnalyticsEvent.interpretationCompleted =>
      'interpretation_completed',
    OperationalAnalyticsEvent.interpretationSuppressed =>
      'interpretation_suppressed',
    OperationalAnalyticsEvent.interpretationFailed => 'interpretation_failed',
    OperationalAnalyticsEvent.retryScheduled => 'retry_scheduled',
    OperationalAnalyticsEvent.retryStarted => 'retry_started',
    OperationalAnalyticsEvent.retryCompleted => 'retry_completed',
    OperationalAnalyticsEvent.retryExhausted => 'retry_exhausted',
    OperationalAnalyticsEvent.vaultWriteStarted => 'vault_write_started',
    OperationalAnalyticsEvent.vaultWriteCompleted => 'vault_write_completed',
    OperationalAnalyticsEvent.vaultWriteFailed => 'vault_write_failed',
    OperationalAnalyticsEvent.syncStarted => 'sync_started',
    OperationalAnalyticsEvent.syncCompleted => 'sync_completed',
    OperationalAnalyticsEvent.syncFailed => 'sync_failed',
    OperationalAnalyticsEvent.recoveryStarted => 'recovery_started',
    OperationalAnalyticsEvent.recoveryCompleted => 'recovery_completed',
    OperationalAnalyticsEvent.recoveryFailed => 'recovery_failed',
    OperationalAnalyticsEvent.purchaseStarted => 'purchase_started',
    OperationalAnalyticsEvent.purchaseCompleted => 'purchase_completed',
    OperationalAnalyticsEvent.purchaseFailed => 'purchase_failed',
    OperationalAnalyticsEvent.restoreCompleted => 'restore_completed',
    OperationalAnalyticsEvent.restoreFailed => 'restore_failed',
    OperationalAnalyticsEvent.deletionStarted => 'deletion_started',
    OperationalAnalyticsEvent.deletionCompleted => 'deletion_completed',
    OperationalAnalyticsEvent.deletionFailed => 'deletion_failed',
    OperationalAnalyticsEvent.exportStarted => 'export_started',
    OperationalAnalyticsEvent.exportCompleted => 'export_completed',
    OperationalAnalyticsEvent.exportFailed => 'export_failed',
  });

  static const AnalyticsEventId _pricingValidationSeen = AnalyticsEventId._(
    'pricing_validation_seen',
  );
  static const AnalyticsEventId _pricingValidationValueStateSelected =
      AnalyticsEventId._('pricing_validation_value_state_selected');
  static const AnalyticsEventId _pricingValidationReasonSelected =
      AnalyticsEventId._('pricing_validation_reason_selected');
  static const AnalyticsEventId _pricingValidationCtaTapped =
      AnalyticsEventId._('pricing_validation_cta_tapped');

  static AnalyticsEventId pricingValidationEvent(
    CatalogPricingValidationEvent event,
  ) => switch (event) {
    CatalogPricingValidationEvent.seen => _pricingValidationSeen,
    CatalogPricingValidationEvent.valueStateSelected =>
      _pricingValidationValueStateSelected,
    CatalogPricingValidationEvent.reasonSelected =>
      _pricingValidationReasonSelected,
    CatalogPricingValidationEvent.ctaTapped => _pricingValidationCtaTapped,
  };

  static String pricingValueStateToken(CatalogPricingValueState value) =>
      switch (value) {
        CatalogPricingValueState.monthlyStorePlan => 'monthly_store_plan',
        CatalogPricingValueState.annualStorePlan => 'annual_store_plan',
        CatalogPricingValueState.needsMoreValue => 'needs_more_value',
        CatalogPricingValueState.wouldNotSubscribe => 'would_not_subscribe',
      };

  static String pricingReasonToken(CatalogPricingReason value) =>
      switch (value) {
        CatalogPricingReason.moreProofOverTime => 'more_proof_over_time',
        CatalogPricingReason.betterCorrections => 'better_corrections',
        CatalogPricingReason.clearerTimeline => 'clearer_timeline',
        CatalogPricingReason.lowerPrice => 'lower_price',
      };

  // Historical ids remain only to document rejected pre-V1 telemetry.
  // ignore: unused_field
  static const Set<String> _legacyEventIds = {
    'post_save_observation_shown',
    'post_save_no_conclusion',
    'auditable_conclusion_shown',
    'insight_displayed',
    'evidence_receipt_opened',
    'exact_source_opened',
    'interpretation_corrected',
    'interpretation_feedback_submitted',
    'conclusion_suppressed',
    'early_comparison_shown',
    'reliable_change_displayed',
    'archive_search_used',
    'changes_viewed',
    'insight_not_displayed_low_evidence',
    'archive_evidence_skipped_placeholder',
    'quick_text_capture_started',
    'quick_text_capture_abandoned',
    'quick_text_capture_saved',
    'return_reason_generated',
    'immediate_discovery_surfaced',
    'archive_evolution_after_recording',
    'instant_reflection_surfaced',
    'paywall_proof_seen',
    'immediate_discovery_why_opened',
    'immediate_discovery_evidence_opened',
    'daily_discovery_surfaced',
    'daily_discovery_why_opened',
    'return_reason_record_tapped',
    'archive_challenge_surfaced',
    'archive_challenge_why_opened',
    'start_here_shown',
    'start_here_selected',
    'example_prompt_shown',
    'example_prompt_tapped',
    'surprise_opened',
    'surprise_ignored',
    'surprise_shared',
    'surprise_surfaced',
    'instant_belief_viewed',
    'instant_belief_evidence_opened',
    'discovery_banner_opened',
    'weekly_story_viewed',
    'weekly_story_opened',
    'evidence_opened',
    'evidence_record_opened',
    'progress_identity_viewed',
    'most_important_insight_opened',
    'archive_was_wrong_opened',
    'belief_under_review_opened',
    'what_changed_today_opened',
    'discovery_streak_viewed',
    'living_archive_view_all_discoveries',
    'early_insight_shown',
    'early_insight_opened',
    'discover_opened',
    'belief_expanded',
    'theme_expanded',
    'contradiction_viewed',
    'blind_spot_viewed',
    'chapter_opened',
    'archive_question_asked',
    'archive_why_opened',
    'archive_deeper_opened',
    'archive_contradiction_opened',
    'archive_timeline_opened',
    'archive_related_theme_opened',
    'archive_surprise_viewed',
    'archive_challenge_viewed',
    'interpretation_opened',
    'interpretation_completed',
    'followup_question_viewed',
    'followup_question_used',
    'interpretation_go_deeper_opened',
    'archive_evolution_seen',
    'archive_evolution_opened',
    'archive_evolution_ignored',
    'archive_evolution_completed',
    'discovery_share_tapped',
    'discovery_shared',
    'recording_created',
    'recording_day1',
    'recording_day3',
    'recording_day7',
    'recording_day_1',
    'recording_day_3',
    'recording_day_7',
    'archive_opened',
    'theory_opened',
    'deep_dive_opened',
    'paywall_seen',
    'paywall_dismissed',
    'purchase_started',
    'purchase_completed',
    'share_card_opened',
    'share_card_shared',
    'playback_started',
    'playback_completed',
    'playback_scrubbed',
    'post_save_detail_prompt_tapped',
    'post_save_detail_saved',
    'post_save_detail_failed',
    'early_saved_moments_viewed',
  };

  /// Events that may cross the production provider boundary in commercial V1.
  static const Set<String> _v1EventIds = {
    'first_core_loop_completed',
    'post_save_observation_shown',
    'post_save_no_conclusion',
    'auditable_conclusion_shown',
    'evidence_receipt_opened',
    'exact_source_opened',
    'interpretation_feedback_submitted',
    'interpretation_corrected',
    'conclusion_suppressed',
    'early_comparison_shown',
    'reliable_change_displayed',
    'changes_viewed',
    'archive_search_used',
    'insight_not_displayed_low_evidence',
    'archive_evidence_skipped_placeholder',
    // Structural product-validation funnel. Each records that a step happened,
    // never what the user wrote.
    'first_capture_started',
    'first_capture_saved',
    'transcript_reviewed',
    'first_valid_observation_delivered',
    'second_entry_saved',
    'first_valid_comparison_delivered',
    'changes_opened',
    'change_thread_opened',
    'weekly_review_opened',
    'paywall_shown_after_value',
    'restore_completed',
    'export_completed',
    'purchase_started',
    'purchase_completed',
    'playback_started',
    'playback_completed',
    'start_here_shown',
    'start_here_selected',
    'account_signup_started',
    'account_signup_completed',
    'account_signin_started',
    'account_signin_completed',
    'account_signout',
    'auth_error_shown',
    'app_lock_enabled',
    'app_lock_disabled',
    'app_lock_unlocked',
    'app_lock_failed',
    'biometric_unlock_attempted',
    'biometric_unlock_succeeded',
    'biometric_unlock_failed',
    'original_save_started',
    'original_save_completed',
    'original_save_failed',
    'transcription_started',
    'transcription_completed',
    'transcription_failed',
    'interpretation_started',
    'interpretation_completed',
    'interpretation_suppressed',
    'interpretation_failed',
    'retry_scheduled',
    'retry_started',
    'retry_completed',
    'retry_exhausted',
    'vault_write_started',
    'vault_write_completed',
    'vault_write_failed',
    'sync_started',
    'sync_completed',
    'sync_failed',
    'recovery_started',
    'recovery_completed',
    'recovery_failed',
    'purchase_failed',
    'restore_failed',
    'deletion_started',
    'deletion_completed',
    'deletion_failed',
    'export_started',
    'export_failed',
  };

  /// Legacy funnel events remain accepted through one constrained compatibility
  /// boundary while their many call sites migrate to typed ids. Names must be
  /// stable snake-case lifecycle metadata and use a catalogued action suffix.
  // Historical grammar is intentionally no longer accepted by production.
  // ignore: unused_field
  static const Set<String> _activationSuffixes = {
    'accepted',
    'action',
    'allowed',
    'answered',
    'applied',
    'attempted',
    'available',
    'blocked',
    'calibrated',
    'cancelled',
    'changed',
    'checked',
    'completed',
    'confirmed',
    'connected',
    'context',
    'copied',
    'created',
    'declined',
    'denied',
    'deleted',
    'dismissed',
    'disabled',
    'enabled',
    'expanded',
    'exported',
    'failed',
    'feedback',
    'fresh',
    'ignored',
    'important',
    'opened',
    'original',
    'personal',
    'pinned',
    'removed',
    'requested',
    'reset',
    'resolved',
    'saved',
    'scored',
    'save',
    'seen',
    'selected',
    'shared',
    'share',
    'shown',
    'signin',
    'signout',
    'started',
    'succeeded',
    'suppressed',
    'surfaced',
    'tapped',
    'unlocked',
    'unpinned',
    'updated',
    'used',
    'useful',
    'viewed',
    'copy',
    'offered',
    'quite',
    'received',
    'recorded',
    'related',
    'separate',
    'set',
    'surface',
    'thread',
  };

  static const Set<String> countBuckets = {
    'none',
    'one',
    'two',
    'few',
    'some',
    'many',
    'three_plus',
  };

  static const Set<String> flagValues = {
    '0',
    '1',
    'false',
    'true',
    'no',
    'yes',
  };

  static const Set<String> _bucketKeys = {
    'action_item_count_bucket',
    'char_count_bucket',
    'change_count_bucket',
    'collection_count_bucket',
    'days_since_seen_bucket',
    'days_since_set_bucket',
    'duration_seconds_bucket',
    'entry_count_band',
    'entry_count_bucket',
    'evidence_count',
    'evidence_count_band',
    'evidence_recording_count_bucket',
    'milestone_count_bucket',
    'item_count_bucket',
    'phrase_count_bucket',
    'position_seconds_bucket',
    'record_count_bucket',
    'reflection_count_bucket',
    'result_count_bucket',
    'selection_count_bucket',
    'theme_count_bucket',
    'theory_count_bucket',
  };

  static const Set<String> _flagKeys = {
    'enabled',
    'has_change',
    'has_action_phrase',
    'has_confirmed_repeat',
    'has_connected_thread',
    'has_custom_name',
    'has_free_text',
    'has_helped',
    'has_parent_entry',
    'has_first_proof',
    'has_pattern_detail_cta',
    'has_phrase',
    'has_real_timeline',
    'has_useful_proof',
    'has_response',
    'has_snippets',
    'has_strong_evidence',
    'has_watch_target',
    'is_value_moment',
    'reliable_change_available',
    'used_fallback',
    'was_evidence',
  };

  static const Set<String> _tokenKeys = {
    'action_type',
    'answer',
    'answer_type',
    'authority_state',
    'capture_mode',
    'capture_type',
    'card_type',
    'comparison_state',
    'conclusion_kind',
    'confidence_band',
    'connection_mode',
    'context',
    'current_intent',
    'decision_id',
    'detail_type',
    'entry_aboutness',
    'entry_memory_mode',
    'error_type',
    'export_method',
    'fact_type',
    'feedback',
    'filter_type',
    'format',
    'influence_level',
    'kind',
    'lifecycle_state',
    'line_id',
    'memory_scope',
    'method',
    'option_type',
    'origin',
    'period',
    'plan',
    'preservation_source',
    'priority_band',
    'prompt_type',
    'reason',
    'reason_id',
    'ref',
    'relation_state',
    'relevance',
    'relevance_band',
    'reliability_state',
    'score_band',
    'share_type',
    'source',
    'source_type',
    'stage',
    'status',
    'step',
    'suggested_action',
    'surface',
    'surface_type',
    'surfacing_mode',
    'thread_scope',
    'type',
    'ui_origin',
    'variant',
  };

  static final Map<String, AnalyticsPropertySpec> propertySpecs =
      UnmodifiableMapView({
        for (final key in _bucketKeys)
          key: AnalyticsPropertySpec(
            AnalyticsValueKind.bucket,
            allowedValues: countBuckets,
          ),
        for (final key in _flagKeys)
          key: AnalyticsPropertySpec(
            AnalyticsValueKind.flag,
            allowedValues: flagValues,
          ),
        for (final key in _tokenKeys)
          key: const AnalyticsPropertySpec(AnalyticsValueKind.token),
        'cohort_day': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: {'1', '3', '7'},
        ),
        // Latency is reported as a coarse band. A millisecond figure is a
        // device fingerprinting signal and is never sent.
        'performance_duration_band': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: performanceDurationBands,
        ),
        'time_band': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: timeBands,
        ),
        'feedback_choice': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: feedbackChoices,
        ),
        'access_decision': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: accessDecisions,
        ),
        'subscription_state': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: subscriptionStates,
        ),
        'failure_reason_band': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: failureCategories,
        ),
        'attempt_band': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: attemptBands,
        ),
        'operation_source': const AnalyticsPropertySpec(
          AnalyticsValueKind.bucket,
          allowedValues: operationSources,
        ),
      });

  /// Coarse latency bands. Callers pass a band, never a raw duration.
  static const Set<String> performanceDurationBands = {
    'under_200ms',
    'under_500ms',
    'under_1s',
    'under_2s',
    'under_5s',
    'over_5s',
  };

  /// How long after a reference point something happened.
  static const Set<String> timeBands = {
    'same_session',
    'within_24h',
    'within_72h',
    'within_7d',
    'over_7d',
  };

  static const Set<String> feedbackChoices = {
    'accurate',
    'wrong_angle',
    'too_generic',
    'hide',
  };

  static const Set<String> accessDecisions = {
    'allowed',
    'denied_pro_required',
    'denied_quota',
    'denied_not_eligible',
  };

  static const Set<String> subscriptionStates = {
    'free',
    'pro_active',
    'pro_expired',
    'pro_grace',
  };

  static const Set<String> failureCategories = {
    'offline',
    'timeout',
    'provider_unavailable',
    'permission_denied',
    'authentication',
    'validation',
    'storage_unavailable',
    'quota',
    'cancelled',
    'unknown',
  };

  static const Set<String> attemptBands = {'first', 'second', 'third_or_more'};

  static const Set<String> operationSources = {
    'voice',
    'text',
    'import',
    'manual',
    'background',
    'system',
  };

  /// Maps a measured duration onto a band. Kept beside the allowlist so the
  /// two cannot drift apart.
  static String durationBand(Duration value) {
    final ms = value.inMilliseconds;
    if (ms < 200) return 'under_200ms';
    if (ms < 500) return 'under_500ms';
    if (ms < 1000) return 'under_1s';
    if (ms < 2000) return 'under_2s';
    if (ms < 5000) return 'under_5s';
    return 'over_5s';
  }

  static final RegExp _safeId = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static final RegExp _sensitiveKey = RegExp(
    r'(?:^|_)(?:email|token|secret|password|customer_id|user_id|account_id|'
    r'entry_id|archive_id|memory_id|product_id|transcript|'
    r'evidence_(?:text|quote|content)|conclusion_(?:text|statement|content)|'
    r'correction_note|question|prompt|prompt_text|theme|topic_label|title|'
    r'filename|file_name|filepath|file_path|path|raw_error|provider_error|'
    r'error_message|stack|stack_trace|recovery_code|sync_key|category|hash|'
    r'timestamp)(?:_|$)',
  );
  static final RegExp _contentMarker = RegExp(
    r'(?:sentinel|private|content|transcript|reflection|@|'
    r'bearer|token|secret|password|sha(?:1|256|512)|md5|journal|quote|'
    r'correction|question|filename|filepath|exception|stacktrace|recovery_code|'
    r'sync_key|health|relationship|money|work_pressure|anxiety|mood|belief|'
    r'trait)',
    caseSensitive: false,
  );
  static final RegExp _hashLike = RegExp(r'^[a-f0-9]{16,}$');

  /// The content-marker heuristic exists to catch unreviewed strings that may
  /// carry user text. A curated V1 event id is a fixed constant that has been
  /// read by a human, so a substring collision in the *name* is not evidence of
  /// a leak. Exemptions are listed one by one and never widened to a pattern.
  static const Set<String> _contentMarkerExemptEventIds = {
    // "transcript" appears in the name only; the event carries no transcript.
    'transcript_reviewed',
  };

  static AnalyticsEventId? legacyEvent(String id) {
    final normalized = _normalizeLegacyCoreLoop(id);
    return _v1EventIds.contains(normalized)
        ? AnalyticsEventId._(normalized)
        : null;
  }

  static AnalyticsEventId? activationEvent(String id) {
    if (!_safeId.hasMatch(id)) return null;
    if (_contentMarker.hasMatch(id) &&
        !_contentMarkerExemptEventIds.contains(id)) {
      return null;
    }
    return _v1EventIds.contains(id) ? AnalyticsEventId._(id) : null;
  }

  static String _normalizeLegacyCoreLoop(String id) =>
      id == 'First Core Loop Completed' ? 'first_core_loop_completed' : id;

  static bool isSensitiveKey(String key) =>
      key == 'evidence' || key == 'conclusion' || _sensitiveKey.hasMatch(key);

  static bool isSafeToken(String value) =>
      _safeId.hasMatch(value) &&
      !_contentMarker.hasMatch(value) &&
      !_hashLike.hasMatch(value);

  static String countBucket(num value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'must be finite and non-negative',
      );
    }
    if (value == 0) return 'none';
    if (value <= 1) return 'one';
    if (value <= 3) return 'few';
    if (value <= 10) return 'some';
    return 'many';
  }

  static String bucketedKey(String key) {
    if (key.endsWith('_count')) return '${key}_bucket';
    if (key.endsWith('_seconds')) return '${key}_bucket';
    if (key == 'days_since_set' || key == 'days_since_seen') {
      return '${key}_bucket';
    }
    return key;
  }
}
