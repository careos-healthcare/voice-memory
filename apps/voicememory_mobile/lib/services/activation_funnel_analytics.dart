import 'dart:async';

import 'package:flutter/foundation.dart';

import 'product_analytics.dart';

/// Core activation funnel events — where users drop off between the first
/// session and a Pro purchase.
///
/// Privacy by construction:
/// - Event names are fixed constants; nothing dynamic.
/// - Only whitelisted property keys exist ([allowedPropertyKeys]), passed as
///   typed named parameters — there is no free-form property map.
/// - String property values must look like stable ids
///   (lowercase `a-z0-9_`, max 40 chars); anything else — including any
///   user note, snippet, transcript, or belief phrase — is dropped.
/// - "Seen" events de-dupe per app session so widget rebuilds never spam.
///
/// Events are forwarded to the existing [ProductAnalytics] pipeline
/// (Firebase when configured, debug log otherwise). `paywall_seen`,
/// `purchase_started`, and `purchase_completed` complete the funnel from the
/// existing paywall attribution flow.
abstract final class ActivationFunnelAnalytics {
  ActivationFunnelAnalytics._();

  static const String firstSessionCardSeen = 'first_session_card_seen';
  static const String twoDayActivationSeen = 'two_day_activation_seen';
  static const String oneSmallRecordingSeen = 'one_small_recording_seen';
  static const String recordCtaTapped = 'record_cta_tapped';
  static const String firstRecordingSaved = 'first_recording_saved';

  /// First Save Rescue — the zero-entry "Try a 10-second test" helper.
  /// `saved` fires when the very first save follows a rescue-started
  /// recording. Counts only — never recording content.
  static const String firstSaveRescueSeen = 'first_save_rescue_seen';
  static const String firstSaveRescueTapped = 'first_save_rescue_tapped';
  static const String firstSaveRescueSaved = 'first_save_rescue_saved';

  /// First Recording Sample — the zero-entry starter sentence. `saved`
  /// fires when the very first save follows a starter-seeded recording.
  /// Counts only — never recording content.
  static const String firstRecordingSampleSeen = 'first_recording_sample_seen';
  static const String firstRecordingSampleTapped =
      'first_recording_sample_tapped';
  static const String firstRecordingSampleSaved =
      'first_recording_sample_saved';

  /// First-save confidence lines (privacy/reversibility + "one sentence is
  /// enough") rendered for users with an empty archive.
  static const String firstSaveConfidenceSeen = 'first_save_confidence_seen';
  static const String doneForTodaySeen = 'done_for_today_seen';
  static const String day1CompleteSeen = 'day_1_complete_seen';

  /// The concrete day-1 return reason ("did this return, fade, or change?")
  /// rendered after the very first save.
  static const String day1ReturnReasonSeen = 'day_1_return_reason_seen';

  /// Day 7 Continuity Loop — calm continuity copy after the Day 2 return,
  /// closing into the existing weekly review. Counts and stable stage ids
  /// only — never content.
  static const String day7ContinuitySeen = 'day_7_continuity_seen';
  static const String day7ContinuityWeeklyReviewTapped =
      'day_7_continuity_weekly_review_tapped';

  static const String day2ReturnSeen = 'day_2_return_seen';

  /// Day 2 Gentle Reminder — one optional reminder offered once after the
  /// very first save. Counts only; the answer ids are fixed event names.
  static const String day2ReminderPromptSeen = 'day_2_reminder_prompt_seen';
  static const String day2ReminderAccepted = 'day_2_reminder_accepted';
  static const String day2ReminderDeclined = 'day_2_reminder_declined';
  static const String day2ReminderPermissionDenied =
      'day_2_reminder_permission_denied';
  static const String day2ReminderOpened = 'day_2_reminder_opened';
  static const String threadReturnEvidenceSeen = 'thread_return_evidence_seen';
  static const String beliefDistanceSeen = 'belief_distance_seen';
  static const String weeklyThreadReviewSeen = 'weekly_thread_review_seen';
  static const String archiveProofCounterSeen = 'archive_proof_counter_seen';
  static const String valueMomentProBridgeSeen = 'value_moment_pro_bridge_seen';
  static const String valueMomentProBridgeTapped =
      'value_moment_pro_bridge_tapped';

  /// One-tap "Was this useful?" answers on value cards. Carries only
  /// `card_type` plus pre-approved counts — never card text.
  static const String valueFeedbackUseful = 'value_feedback_useful';
  static const String valueFeedbackNotQuite = 'value_feedback_not_quite';

  /// A voluntary testimonial was saved after a useful-rating. Metadata only
  /// (`card_type` + counts) — the quote itself stays local and never enters
  /// any analytics payload.
  static const String valueTestimonialSaved = 'value_testimonial_saved';

  /// One-tap "What held you back?" capture after a paywall dismissal.
  /// Carries only `source` and a stable `reason` id — never user text.
  static const String paywallRejectionPromptSeen =
      'paywall_rejection_prompt_seen';
  static const String paywallRejectionReasonSelected =
      'paywall_rejection_reason_selected';
  static const String paywallRejectionPromptSkipped =
      'paywall_rejection_prompt_skipped';

  /// The final purchase reassurance block rendered above the purchase CTA.
  static const String purchaseReassuranceSeen = 'purchase_reassurance_seen';

  /// Tomorrow's-check preview shown after the first save.
  static const String day2ReturnPreviewSeen = 'day_2_return_preview_seen';

  /// The above-fold "What Pro continues" clarity block under the headline.
  static const String paywallAboveFoldClaritySeen =
      'paywall_above_fold_clarity_seen';

  /// The price-confidence lines near the plans and purchase CTA.
  static const String priceConfidenceSeen = 'price_confidence_seen';

  /// Objection-specific reassurance block on a later paywall visit.
  static const String paywallObjectionFollowUpSeen =
      'paywall_objection_follow_up_seen';

  /// The plan-choice helper near the plan selector.
  static const String planSelectionConfidenceSeen =
      'plan_selection_confidence_seen';

  /// A plan card was tapped — stable plan id only.
  static const String paywallPlanSelected = 'paywall_plan_selected';

  /// Pro Retention Check — one optional "is the connected archive still
  /// useful?" question for Pro users. Stable ids and counts only.
  static const String proRetentionCheckSeen = 'pro_retention_check_seen';
  static const String proRetentionCheckYes = 'pro_retention_check_yes';
  static const String proRetentionCheckNotYet = 'pro_retention_check_not_yet';

  /// Calm return cue after a purchase start that never completed.
  static const String purchaseIntentReturnCueSeen =
      'purchase_intent_return_cue_seen';
  static const String purchaseIntentReturnCueTapped =
      'purchase_intent_return_cue_tapped';
  static const String purchaseIntentReturnCueDismissed =
      'purchase_intent_return_cue_dismissed';

  /// Fired by the existing paywall flow (kept here so the funnel reads as
  /// one list): `paywall_seen` via First25 metrics on paywall open, and the
  /// purchase stages forwarded from the paywall attribution events.
  static const String paywallSeen = 'paywall_seen';
  static const String purchaseStarted = 'purchase_started';
  static const String purchaseCompleted = 'purchase_completed';

  /// The only property keys that can ever appear in a funnel payload.
  static const Set<String> allowedPropertyKeys = {
    'entry_count',
    'has_connected_thread',
    'source',
    'stage',
    'card_type',
    'reason',
    'plan',
  };

  /// Stable-id shape for string values — user text never matches this.
  static final RegExp _safeValue = RegExp(r'^[a-z0-9_]{1,40}$');

  static final Set<String> _firedThisSession = <String>{};

  static void Function(String event, Map<String, Object> properties)? _sink;

  /// Logs one funnel event. [oncePerSession] de-dupes by event + stage +
  /// source for "seen" events fired from widget builds.
  static void track(
    String event, {
    int? entryCount,
    bool? hasConnectedThread,
    String? source,
    String? stage,
    String? cardType,
    String? reason,
    String? plan,
    bool oncePerSession = false,
  }) {
    if (oncePerSession) {
      final key = '$event|${stage ?? ''}|${source ?? ''}';
      if (!_firedThisSession.add(key)) return;
    }

    final properties = <String, Object>{
      if (entryCount != null) 'entry_count': entryCount,
      if (hasConnectedThread != null)
        'has_connected_thread': hasConnectedThread ? 1 : 0,
      if (source != null && _safeValue.hasMatch(source)) 'source': source,
      if (stage != null && _safeValue.hasMatch(stage)) 'stage': stage,
      if (cardType != null && _safeValue.hasMatch(cardType))
        'card_type': cardType,
      if (reason != null && _safeValue.hasMatch(reason)) 'reason': reason,
      if (plan != null && _safeValue.hasMatch(plan)) 'plan': plan,
    };

    final sink = _sink;
    if (sink != null) {
      sink(event, Map.unmodifiable(properties));
      return;
    }
    unawaited(
      ProductAnalytics.track(
        event,
        parameters: properties.isEmpty ? null : properties,
      ),
    );
  }

  /// Routes events to [capture] instead of [ProductAnalytics] — for tests.
  @visibleForTesting
  static void captureForTest(
    void Function(String event, Map<String, Object> properties) capture,
  ) {
    _sink = capture;
  }

  @visibleForTesting
  static void resetForTest() {
    _firedThisSession.clear();
    _sink = null;
  }
}
