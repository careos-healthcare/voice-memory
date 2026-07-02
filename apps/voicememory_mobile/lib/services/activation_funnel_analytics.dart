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
abstract class ActivationFunnelAnalytics {
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

  /// Referral invite after a value moment — stable source/card ids only,
  /// never archive content.
  static const String referralInviteSeen = 'referral_invite_seen';
  static const String referralInviteCopied = 'referral_invite_copied';
  static const String referralInviteDismissed = 'referral_invite_dismissed';

  /// The source-specific proof line rendered above the invite body —
  /// stable source/card ids only, never archive content.
  static const String referralProofMomentSeen = 'referral_proof_moment_seen';

  /// User-approved archive belief share card — stable source, card type,
  /// and generalized line ids only; the line text itself is a compile-time
  /// constant and never enters analytics. `copied` also covers the system
  /// share sheet (same user-approved text leaving the app).
  static const String archiveBeliefShareCardSeen =
      'archive_belief_share_card_seen';
  static const String archiveBeliefShareLineSelected =
      'archive_belief_share_line_selected';
  static const String archiveBeliefShareCopied = 'archive_belief_share_copied';
  static const String archiveBeliefShareDismissed =
      'archive_belief_share_dismissed';

  /// App Store review prompt after a value moment — stable source/card
  /// ids and counts only, never archive content.
  static const String reviewPromptSeen = 'review_prompt_seen';
  static const String reviewPromptTapped = 'review_prompt_tapped';
  static const String reviewPromptDismissed = 'review_prompt_dismissed';

  /// The copied invite included the attribution link — fixed ref plus a
  /// whitelisted source id, never the invite text itself.
  static const String referralInviteLinkCopied = 'referral_invite_link_copied';

  /// An `/invite?ref=archive_invite` deep link was opened. Fixed ref and a
  /// whitelisted source id only.
  static const String inviteAttributionReceived = 'invite_attribution_received';

  /// Invited User Welcome — the source-tailored welcome before the first
  /// save. `first_save` fires when the very first save follows a
  /// welcome-started recording. Stable source ids and counts only.
  static const String invitedUserWelcomeSeen = 'invited_user_welcome_seen';
  static const String invitedUserWelcomeTapped = 'invited_user_welcome_tapped';
  static const String invitedUserFirstSave = 'invited_user_first_save';

  /// Invite funnel mirror events — fired only for users with a first-touch
  /// invite attribution, additive to (never instead of) the normal funnel.
  /// Stable invite source ids and card types only.
  static const String invitedAppOpened = 'invited_app_opened';
  static const String invitedRecordCtaTapped = 'invited_record_cta_tapped';
  static const String invitedFirstSave = 'invited_first_save';
  static const String invitedDay2ReturnSeen = 'invited_day_2_return_seen';
  static const String invitedValueMomentSeen = 'invited_value_moment_seen';
  static const String invitedProBridgeTapped = 'invited_pro_bridge_tapped';
  static const String invitedPaywallSeen = 'invited_paywall_seen';
  static const String invitedPurchaseStarted = 'invited_purchase_started';
  static const String invitedPurchaseCompleted = 'invited_purchase_completed';

  /// Invited Day 2 return copy — the source-tailored second-visit card that
  /// replaces the generic Day 2 card for invited users. Stable invite
  /// source ids and counts only.
  static const String invitedDay2CopySeen = 'invited_day_2_copy_seen';
  static const String invitedDay2CopyTapped = 'invited_day_2_copy_tapped';

  /// Calm return cue after a purchase start that never completed.
  static const String purchaseIntentReturnCueSeen =
      'purchase_intent_return_cue_seen';
  static const String purchaseIntentReturnCueTapped =
      'purchase_intent_return_cue_tapped';
  static const String purchaseIntentReturnCueDismissed =
      'purchase_intent_return_cue_dismissed';

  /// App lock — optional PIN/biometric protection. Method and enabled-state
  /// ids only; no PIN, hash, salt, or archive content has a path in.
  static const String appLockEnabled = 'app_lock_enabled';
  static const String appLockDisabled = 'app_lock_disabled';
  static const String appLockUnlocked = 'app_lock_unlocked';
  static const String appLockFailed = 'app_lock_failed';
  static const String biometricUnlockAttempted = 'biometric_unlock_attempted';
  static const String biometricUnlockSucceeded = 'biometric_unlock_succeeded';
  static const String biometricUnlockFailed = 'biometric_unlock_failed';

  /// Account flow — the existing backend email + one-time-code provider
  /// (passwordless). Method and stable error ids only; no email, code,
  /// password, or archive content has a path in. `password_reset_requested`
  /// is reserved: the provider is passwordless today, so it can only fire
  /// if a password flow ever ships.
  static const String accountSignupStarted = 'account_signup_started';
  static const String accountSignupCompleted = 'account_signup_completed';
  static const String accountSigninStarted = 'account_signin_started';
  static const String accountSigninCompleted = 'account_signin_completed';
  static const String accountSignout = 'account_signout';
  static const String passwordResetRequested = 'password_reset_requested';
  static const String authErrorShown = 'auth_error_shown';

  /// Memory Relevance Gate — how strongly the archive may speak about the
  /// present, and the user's opt-outs. Fixed relevance levels and stable
  /// card ids only; no note, snippet, or belief phrase has a path in.
  static const String memoryRelevanceSeen = 'memory_relevance_seen';
  static const String memoryMarkedNotRelated = 'memory_marked_not_related';
  static const String freshEntrySelected = 'fresh_entry_selected';
  static const String saveWithoutConnectingSelected =
      'save_without_connecting_selected';

  /// "Treat this as new" — the per-entry control that keeps one save out
  /// of immediate connection claims. Counts and the enabled flag only;
  /// never entry text.
  static const String treatAsNewSeen = 'treat_as_new_seen';
  static const String treatAsNewSelected = 'treat_as_new_selected';
  static const String treatAsNewSaved = 'treat_as_new_saved';

  /// Memory Controls — per-card "Why this appeared" sheet and the
  /// "Memory used" indicator. Stable card ids and the fixed connection
  /// mode only; the sheet itself is compile-time copy.
  static const String memoryWhyThisAppearedOpened =
      'memory_why_this_appeared_opened';
  static const String memoryUsedIndicatorSeen = 'memory_used_indicator_seen';

  /// Memory Scope — the persistent setting for when ArchiveMe connects
  /// entries, plus the ask-mode connect prompt. Fixed scope ids and
  /// counts only; never entry text.
  static const String memoryScopeSeen = 'memory_scope_seen';
  static const String memoryScopeChanged = 'memory_scope_changed';
  static const String memoryOffNoticeSeen = 'memory_off_notice_seen';
  static const String memoryConnectPromptSeen = 'memory_connect_prompt_seen';
  static const String memoryConnectConfirmed = 'memory_connect_confirmed';
  static const String memoryTreatAsNewSelected = 'memory_treat_as_new_selected';
  static const String memoryTreatAsNewSaved = 'memory_treat_as_new_saved';

  /// Entry memory scope + thread picker on the record screen.
  static const String entryMemoryScopeSeen = 'entry_memory_scope_seen';
  static const String entryMemoryModeSelected = 'entry_memory_mode_selected';
  static const String entryThreadScopeSeen = 'entry_thread_scope_seen';
  static const String entryThreadScopeSelected = 'entry_thread_scope_selected';
  static const String archiveThreadCreated = 'archive_thread_created';
  static const String entryAssignedToThread = 'entry_assigned_to_thread';
  static const String entrySavedKeepSeparate = 'entry_saved_keep_separate';
  static const String entrySavedUseArchiveContext =
      'entry_saved_use_archive_context';

  /// Archive Retrieval Scoring — how strongly the archive was allowed to
  /// inform a memory card. Fixed score bands, counts, and stable card
  /// ids only; no note, snippet, or score number has a path in.
  static const String archiveRetrievalScored = 'archive_retrieval_scored';
  static const String archiveRetrievalUsed = 'archive_retrieval_used';
  static const String archiveRetrievalEmpty = 'archive_retrieval_empty';

  /// "Keep exact details" — the per-entry flag that keeps one save out
  /// of generalized memory summaries while it stays normal evidence.
  /// Counts and the enabled flag only; never entry text.
  static const String keepExactDetailsSelected = 'keep_exact_details_selected';
  static const String keepExactDetailsSaved = 'keep_exact_details_saved';

  /// Memory inspect/edit controls — the privacy-safe evidence list and
  /// per-card connection rules. Stable card ids and counts only; the
  /// list itself shows safe metadata, never note text.
  static const String memoryShowEvidenceOpened = 'memory_show_evidence_opened';
  static const String memoryKeepConnected = 'memory_keep_connected';
  static const String memoryFutureFreshRuleCreated =
      'memory_future_fresh_rule_created';

  /// Visible Memory Controls — receipts, correction actions, cross-thread
  /// confirmation, fresh-next-entry, and reliability checks. Stable ids
  /// only; never entry text, thread names, or snippets.
  static const String memoryUsedReceiptSeen = 'memory_used_receipt_seen';
  static const String memoryUsedReceiptOpened = 'memory_used_receipt_opened';
  static const String memoryConnectionKeepConnected =
      'memory_connection_keep_connected';
  static const String memoryConnectionWrongThread =
      'memory_connection_wrong_thread';
  static const String memoryConnectionNotRelated =
      'memory_connection_not_related';
  static const String memoryConnectionFutureFresh =
      'memory_connection_future_fresh';
  static const String crossThreadConfirmationSeen =
      'cross_thread_confirmation_seen';
  static const String crossThreadConnectionConfirmed =
      'cross_thread_connection_confirmed';
  static const String crossThreadConnectionKeptSeparate =
      'cross_thread_connection_kept_separate';
  static const String freshNextEntryEnabled = 'fresh_next_entry_enabled';
  static const String freshNextEntryApplied = 'fresh_next_entry_applied';
  static const String memoryReliabilityChecked = 'memory_reliability_checked';

  /// Archive Packs — bounded memory areas. Counts and stable ids only;
  /// pack names and instructions never enter any payload.
  static const String archivePacksOpened = 'archive_packs_opened';
  static const String archivePackCreated = 'archive_pack_created';
  static const String entryAssignedToPack = 'entry_assigned_to_pack';
  static const String archivePackOpened = 'archive_pack_opened';
  static const String archivePackInstructionsSaved =
      'archive_pack_instructions_saved';
  static const String crossPackConfirmationSeen =
      'cross_pack_confirmation_seen';
  static const String crossPackConnectionConfirmed =
      'cross_pack_connection_confirmed';
  static const String crossPackConnectionKeptSeparate =
      'cross_pack_connection_kept_separate';
  static const String archivePackExportStarted = 'archive_pack_export_started';
  static const String archivePackExportCompleted =
      'archive_pack_export_completed';

  /// Remember This / Action Items — user-confirmed follow-ups only.
  /// Counts and stable ids only; title, note, and entry text never
  /// enter any payload.
  static const String rememberThisTapped = 'remember_this_tapped';
  static const String actionItemCreated = 'action_item_created';
  static const String actionItemUpdated = 'action_item_updated';
  static const String actionItemMarkedDone = 'action_item_marked_done';
  static const String actionItemDismissed = 'action_item_dismissed';
  static const String actionItemsOpened = 'action_items_opened';
  static const String actionItemSourceOpened = 'action_item_source_opened';
  static const String actionItemExportStarted = 'action_item_export_started';
  static const String actionItemExportCompleted =
      'action_item_export_completed';

  /// Memory governance — whether archive context may matter right now.
  static const String memoryGovernanceChecked = 'memory_governance_checked';
  static const String memoryGovernanceAllowed = 'memory_governance_allowed';
  static const String memoryGovernanceBlocked = 'memory_governance_blocked';
  static const String memoryGovernanceConfirmationRequired =
      'memory_governance_confirmation_required';
  static const String memoryBackgroundOnly = 'memory_background_only';

  /// Topic shift guard — adjacent archive context vs new entry direction.
  static const String topicShiftChecked = 'topic_shift_checked';
  static const String topicShiftPromptSeen = 'topic_shift_prompt_seen';
  static const String topicShiftUseArchiveContext =
      'topic_shift_use_archive_context';
  static const String topicShiftKeepSeparate = 'topic_shift_keep_separate';
  static const String topicShiftStartNewThread = 'topic_shift_start_new_thread';
  static const String topicShiftPromptDismissed =
      'topic_shift_prompt_dismissed';

  /// Entry aboutness — hypothetical / not-about-me modes.
  static const String entryAboutnessPickerSeen = 'entry_aboutness_picker_seen';
  static const String entryAboutnessSelected = 'entry_aboutness_selected';
  static const String entrySavedNonPersonal = 'entry_saved_non_personal';
  static const String entryAboutnessChanged = 'entry_aboutness_changed';
  static const String nonPersonalMemoryBlocked = 'non_personal_memory_blocked';

  /// Sensitive / do-not-surface surfacing guard.
  static const String memorySurfacingPickerSeen =
      'memory_surfacing_picker_seen';
  static const String memorySurfacingSelected = 'memory_surfacing_selected';
  static const String entrySavedSensitive = 'entry_saved_sensitive';
  static const String entrySavedDoNotSurface = 'entry_saved_do_not_surface';
  static const String entrySurfacingChanged = 'entry_surfacing_changed';
  static const String sensitiveSurfacingBlocked = 'sensitive_surfacing_blocked';
  static const String doNotSurfaceBlocked = 'do_not_surface_blocked';
  static const String sensitiveSurfacingUserOpened =
      'sensitive_surfacing_user_opened';

  /// Curated memory preservation — preserve-original guard.
  static const String preserveOriginalSelected = 'preserve_original_selected';
  static const String preserveOriginalRemoved = 'preserve_original_removed';
  static const String originalEvidenceOpened = 'original_evidence_opened';
  static const String curatedMemoryPreservationApplied =
      'curated_memory_preservation_applied';
  static const String summarySeparatedFromOriginal =
      'summary_separated_from_original';

  /// Project Details / Fact Ledger — user-created discrete facts.
  /// Counts and stable ids only; label, value, note never enter payloads.
  static const String saveDetailTapped = 'save_detail_tapped';
  static const String factCreated = 'fact_created';
  static const String factUpdated = 'fact_updated';
  static const String factDeleted = 'fact_deleted';
  static const String factPinned = 'fact_pinned';
  static const String detailsOpened = 'details_opened';
  static const String factSourceOpened = 'fact_source_opened';
  static const String factExportStarted = 'fact_export_started';
  static const String factExportCompleted = 'fact_export_completed';

  /// Memory priority — evidence ordering after relevance governance.
  static const String memoryPriorityChecked = 'memory_priority_checked';
  static const String memoryPrioritySuppressed = 'memory_priority_suppressed';
  static const String memoryPriorityBackgroundOnly =
      'memory_priority_background_only';
  static const String memoryPriorityUsed = 'memory_priority_used';
  static const String memoryNotImportantSelected =
      'memory_not_important_selected';
  static const String memoryPriorityExplanationOpened =
      'memory_priority_explanation_opened';

  /// Archive Search 2.0 — local entry search and filters. Stable filter
  /// types and result-count buckets only; the query text, matched
  /// entries, and tag values never enter any payload.
  static const String archiveSearchOpened = 'archive_search_opened';
  static const String archiveSearchFilterUsed = 'archive_search_filter_used';
  static const String archiveSearchResultOpened =
      'archive_search_result_opened';

  /// Pins / Saved Evidence — pin toggles and the pinned screen. Counts
  /// and stable source ids only; never entry text or entry ids.
  static const String entryPinned = 'entry_pinned';
  static const String entryUnpinned = 'entry_unpinned';
  static const String pinnedEvidenceOpened = 'pinned_evidence_opened';

  /// Collections — user-created groups of entries. Counts and stable
  /// source ids only; collection names are user-private text and never
  /// enter any payload.
  static const String collectionsOpened = 'collections_opened';
  static const String collectionCreated = 'collection_created';
  static const String collectionOpened = 'collection_opened';
  static const String collectionEntryAdded = 'collection_entry_added';
  static const String collectionEntryRemoved = 'collection_entry_removed';
  static const String collectionDeleted = 'collection_deleted';
  static const String collectionFilterUsed = 'collection_filter_used';

  /// Select + Export + Bulk Actions — multi-select over archive
  /// surfaces. Fixed action/format ids and coarse selection buckets
  /// only; exported text, entry text, and collection names never enter
  /// any payload.
  static const String archiveSelectModeStarted = 'archive_select_mode_started';
  static const String archiveBulkActionStarted = 'archive_bulk_action_started';
  static const String archiveBulkActionCompleted =
      'archive_bulk_action_completed';
  static const String archiveBulkActionCancelled =
      'archive_bulk_action_cancelled';
  static const String archiveExportSelectedStarted =
      'archive_export_selected_started';
  static const String archiveExportSelectedCompleted =
      'archive_export_selected_completed';
  static const String archiveBulkDeleteConfirmed =
      'archive_bulk_delete_confirmed';
  static const String archiveBulkArchiveCompleted =
      'archive_bulk_archive_completed';

  /// Memory Authority Framing — the explicit authority and influence
  /// each piece of archive evidence carried into a memory card. Fixed
  /// state/level/reason ids and safe counts only; no note, snippet,
  /// phrase, date, or entry id has a path in.
  static const String memoryAuthorityFrameCreated =
      'memory_authority_frame_created';
  static const String memoryInfluenceUsed = 'memory_influence_used';
  static const String memoryInfluenceSuppressed = 'memory_influence_suppressed';
  static const String memoryAuthorityFramingOpened =
      'memory_authority_framing_opened';

  /// First 60 Seconds — the commercial onboarding loop (record once, see
  /// value, return tomorrow, understand Pro). Counts, stable stage/source
  /// ids, and the fixed memory scope only — never entry text.
  static const String first60IntroSeen = 'first_60_intro_seen';
  static const String first60RecordCtaTapped = 'first_60_record_cta_tapped';
  static const String first60FirstSaveCompleted =
      'first_60_first_save_completed';
  static const String first60ValueCardSeen = 'first_60_value_card_seen';
  static const String first60ArchiveOpened = 'first_60_archive_opened';
  static const String first60ReturnCueSeen = 'first_60_return_cue_seen';
  static const String first60ReturnCueAccepted = 'first_60_return_cue_accepted';
  static const String first60ProBridgeSeen = 'first_60_pro_bridge_seen';
  static const String first60ProBridgeTapped = 'first_60_pro_bridge_tapped';
  static const String first60ProBridgeDismissed =
      'first_60_pro_bridge_dismissed';

  /// Record → Return → Pro — the commercial activation loop. Counts,
  /// stable stage/source ids, and memory scope only — never entry text.
  static const String recordReturnLoopStarted = 'record_return_loop_started';
  static const String recordOnceCtaTapped = 'record_once_cta_tapped';
  static const String firstSaveEvidenceSeen = 'first_save_evidence_seen';
  static const String firstSaveEvidenceViewArchiveTapped =
      'first_save_evidence_view_archive_tapped';
  static const String returnTomorrowSeen = 'return_tomorrow_seen';
  static const String returnTomorrowAccepted = 'return_tomorrow_accepted';
  static const String changeCanBeginSeen = 'change_can_begin_seen';
  static const String proArchiveContinuitySeen = 'pro_archive_continuity_seen';
  static const String proArchiveContinuityTapped =
      'pro_archive_continuity_tapped';
  static const String proArchiveContinuityDismissed =
      'pro_archive_continuity_dismissed';

  /// First Save Commercial Loop (legacy event names — kept for funnels that
  /// shipped before Record → Return → Pro).
  static const String firstSaveEvidenceCardSeen =
      'first_save_evidence_card_seen';
  static const String firstSaveEvidenceRecordAnotherTapped =
      'first_save_evidence_record_another_tapped';
  static const String tomorrowReturnCueSeen = 'tomorrow_return_cue_seen';
  static const String tomorrowReturnCueAccepted =
      'tomorrow_return_cue_accepted';
  static const String firstArchiveValueCardSeen =
      'first_archive_value_card_seen';
  static const String firstArchiveSearchTapped = 'first_archive_search_tapped';
  static const String firstArchivePinTapped = 'first_archive_pin_tapped';
  static const String proContinuityBridgeSeen = 'pro_continuity_bridge_seen';
  static const String proContinuityBridgeTapped =
      'pro_continuity_bridge_tapped';
  static const String proContinuityBridgeDismissed =
      'pro_continuity_bridge_dismissed';
  static const String day2ChangeBridgeSeen = 'day2_change_bridge_seen';
  static const String day2ChangeBridgeRecordTapped =
      'day2_change_bridge_record_tapped';

  /// Repeat recording + Day 2 return loop — counts and stable ids only.
  static const String secondEntryNudgeSeen = 'second_entry_nudge_seen';
  static const String secondEntryNudgeTapped = 'second_entry_nudge_tapped';
  static const String secondEntryNudgeDismissed =
      'second_entry_nudge_dismissed';
  static const String day2ReturnReasonSeen = 'day2_return_reason_seen';
  static const String day2ReturnReasonTapped = 'day2_return_reason_tapped';
  static const String recordAgainCtaSeen = 'record_again_cta_seen';
  static const String recordAgainCtaTapped = 'record_again_cta_tapped';

  /// First honest archive aha moment — stable ids only.
  static const String ahaMomentCandidateFound = 'aha_moment_candidate_found';
  static const String ahaMomentSeen = 'aha_moment_seen';
  static const String ahaMomentShowEvidenceTapped =
      'aha_moment_show_evidence_tapped';
  static const String ahaMomentUseful = 'aha_moment_useful';
  static const String ahaMomentNotQuite = 'aha_moment_not_quite';
  static const String ahaMomentDismissed = 'aha_moment_dismissed';

  /// Pro trust + proof loop — stable ids only.
  static const String archivePrivateReceiptSeen =
      'archive_private_receipt_seen';
  static const String archivePrivateReceiptReviewTapped =
      'archive_private_receipt_review_tapped';
  static const String proValueClaritySeen = 'pro_value_clarity_seen';
  static const String proValueClarityTapped = 'pro_value_clarity_tapped';
  static const String proValueClarityDismissed = 'pro_value_clarity_dismissed';
  static const String ahaProofShareSeen = 'aha_proof_share_seen';
  static const String ahaProofShareTapped = 'aha_proof_share_tapped';
  static const String ahaProofShareDismissed = 'aha_proof_share_dismissed';
  static const String ahaProofShareCopied = 'aha_proof_share_copied';

  /// Copy/share actions on approved share cards — metadata only.
  static const String archiveShareAction = 'archive_share_action';

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
    'has_real_timeline',
    'has_phrase',
    'has_confirmed_repeat',
    'comparison_state',
    'answer',
    'has_strong_evidence',
    'milestone_count',
    'phrase_count',
    'relation_state',
    'source',
    'stage',
    'card_type',
    'reason',
    'plan',
    'ref',
    'method',
    'enabled',
    'error_type',
    'line_id',
    'relevance',
    'connection_mode',
    'memory_scope',
    'entry_memory_mode',
    'thread_scope',
    'score_band',
    'record_count',
    'authority_state',
    'influence_level',
    'reason_id',
    'filter_type',
    'result_count_bucket',
    'collection_count_bucket',
    'action_type',
    'format',
    'selection_count_bucket',
    'reliability_state',
    'pack_count_bucket',
    'decision_id',
    'current_intent',
    'relevance_band',
    'priority_band',
    'status',
    'action_item_count_bucket',
    'suggested_action',
    'entry_aboutness',
    'surfacing_mode',
    'surface_type',
    'preservation_source',
    'fact_type',
    'fact_count_bucket',
    'share_type',
  };

  /// The only values `action_type` can ever carry.
  static const Set<String> allowedActionTypeValues = {
    'export_selected',
    'add_to_collection',
    'pin_selected',
    'unpin_selected',
    'archive_selected',
    'delete_selected',
    'treat_as_new',
    'keep_exact_details',
  };

  /// The only values `format` can ever carry.
  static const Set<String> allowedFormatValues = {'markdown', 'pdf'};

  /// The only values `selection_count_bucket` can ever carry.
  static const Set<String> allowedSelectionCountBucketValues = {
    'none',
    'few',
    'some',
    'many',
  };

  /// The only values `collection_count_bucket` can ever carry.
  static const Set<String> allowedCollectionCountBucketValues = {
    'none',
    'few',
    'some',
    'many',
  };

  /// The only values `filter_type` can ever carry — filter kinds, never
  /// filter values or query text.
  static const Set<String> allowedFilterTypeValues = {
    'keyword',
    'context_tag',
    'date',
    'memory_status',
    'exact_evidence',
    'pinned',
    'archived',
    'clear',
    'pack',
    'action_items',
    'entry_type',
    'surfacing',
    'preserved_original',
    'saved_details',
  };

  /// The only values `fact_type` can ever carry.
  static const Set<String> allowedFactTypeValues = {
    'project_detail',
    'contact',
    'deadline',
    'link',
    'credential_reference',
    'decision',
    'checklist_item',
    'other',
  };

  /// The only values `preservation_source` can ever carry.
  static const Set<String> allowedPreservationSourceValues = {
    'manual',
    'keep_exact_details',
    'pin',
    'action_item',
    'user_confirmed_connection',
    'pack_material',
  };

  /// The only values `result_count_bucket` can ever carry.
  static const Set<String> allowedResultCountBucketValues = {
    'none',
    'few',
    'some',
    'many',
  };

  /// Coarse result-count bucket — counts never leave as exact numbers
  /// tied to a query.
  static String resultCountBucket(int count) {
    if (count <= 0) return 'none';
    if (count <= 3) return 'few';
    if (count <= 10) return 'some';
    return 'many';
  }

  /// The only values `score_band` can ever carry.
  static const Set<String> allowedScoreBandValues = {
    'none',
    'weak',
    'possible',
    'strong',
  };

  /// The only values `authority_state` can ever carry.
  static const Set<String> allowedAuthorityStateValues = {
    'current',
    'repeated',
    'confirmed',
    'stale',
    'superseded',
    'conflicting',
    'duplicate',
    'fresh',
  };

  /// The only values `influence_level` can ever carry.
  static const Set<String> allowedInfluenceLevelValues = {
    'suppress',
    'background',
    'compare',
    'high_authority',
    'blocked',
  };

  /// The only values `reason_id` can ever carry.
  static const Set<String> allowedReasonIdValues = {
    'recent_supported',
    'repeated_supported',
    'user_confirmed',
    'older_unreinforced',
    'changed_later',
    'mixed_evidence',
    'grouped_duplicate',
    'fresh_entry',
    'memory_off',
    'unapproved',
    'first_save',
    'keep_separate',
    'unknown_intent',
    'searching_archive',
    'current_entry',
    'same_thread',
    'same_pack',
    'repeated_evidence',
    'recent_evidence',
    'pinned_evidence',
    'exact_evidence',
    'old_one_off',
    'stale_evidence',
    'not_important',
    'wrong_thread',
    'wrong_pack',
    'not_related',
    'explicit_user_choice',
    'different_thread',
    'different_pack',
  };

  /// The only values `decision_id` can ever carry.
  static const Set<String> allowedDecisionIdValues = {
    'allowed_same_thread',
    'allowed_same_pack',
    'allowed_user_confirmed',
    'blocked_memory_off',
    'blocked_first_save',
    'blocked_fresh_entry',
    'blocked_keep_separate',
    'blocked_wrong_thread',
    'blocked_wrong_pack',
    'blocked_low_relevance',
    'confirm_cross_thread',
    'confirm_cross_pack',
    'background_only',
    'suppressed_fresh',
    'suppressed_keep_separate',
    'suppressed_not_related',
    'suppressed_wrong_thread',
    'suppressed_wrong_pack',
    'suppressed_not_important',
    'background_old_one_off',
    'background_stale',
    'background_mixed',
    'normal_recent_related',
    'important_repeated',
    'important_same_thread',
    'important_same_pack',
    'important_pinned',
    'important_exact',
    'essential_user_confirmed',
    'essential_current_entry',
    'no_shift',
    'new_direction_possible',
    'adjacent_but_unconfirmed',
    'different_thread',
    'different_pack',
    'recent_context_conflict',
    'memory_off',
  };

  /// The only values `entry_aboutness` can ever carry.
  static const Set<String> allowedEntryAboutnessValues = {
    'about_me',
    'hypothetical',
    'not_about_me',
    'project_material',
    'research_note',
  };

  /// The only values `surfacing_mode` can ever carry.
  static const Set<String> allowedSurfacingModeValues = {
    'normal',
    'sensitive',
    'do_not_surface',
  };

  /// The only values `surface_type` can ever carry.
  static const Set<String> allowedSurfaceTypeValues = {
    'search',
    'direct_open',
    'selected_export',
    'pack_detail',
    'pinned_screen',
    'action_items',
    'evidence_inspection',
    'record_context',
    'aha_moment',
    'thread_return',
    'weekly_review',
    'belief_distance',
    'pro_proof',
    'share_card',
  };

  /// The only values `suggested_action` can ever carry.
  static const Set<String> allowedSuggestedActionValues = {
    'use_archive_context',
    'keep_separate',
    'start_new_thread',
    'no_action',
  };

  /// The only values `priority_band` can ever carry.
  static const Set<String> allowedPriorityBandValues = {
    'suppressed',
    'background',
    'normal',
    'important',
    'essential',
  };

  /// The only values `current_intent` can ever carry.
  static const Set<String> allowedCurrentIntentValues = {
    'first_save',
    'fresh_entry',
    'use_archive_context',
    'keep_separate',
    'thread_bound',
    'pack_bound',
    'searching_archive',
    'unknown',
  };

  /// The only values `relevance_band` can ever carry.
  static const Set<String> allowedRelevanceBandValues = {
    'none',
    'low',
    'medium',
    'high',
  };

  /// The only values `memory_scope` can ever carry.
  static const Set<String> allowedMemoryScopeValues = {
    'automatic',
    'ask',
    'thread_only',
    'off',
  };

  static const Set<String> allowedEntryMemoryModeValues = {
    'use_archive_context',
    'treat_as_new',
    'keep_separate',
  };

  static const Set<String> allowedThreadScopeValues = {
    'no_thread',
    'existing_thread',
    'new_thread',
  };

  /// The only values `relevance` can ever carry.
  static const Set<String> allowedRelevanceValues = {
    'fresh',
    'weak',
    'possible',
    'strong',
  };

  /// The only values `connection_mode` can ever carry.
  static const Set<String> allowedConnectionModeValues = {
    'fresh',
    'connected',
    'unapproved',
  };

  static const Set<String> allowedActionItemStatusValues = {
    'open',
    'done',
    'dismissed',
  };

  static const Set<String> allowedShareTypeValues = {
    'copy',
    'share',
    'fallback_copy',
  };

  static const Set<String> allowedShareStatusValues = {
    'copied',
    'shared',
    'fallback_copied',
    'failed',
    'cancelled',
    'unavailable',
  };

  static const Set<String> allowedReliabilityStateValues = {
    'enough_evidence',
    'low_evidence',
    'mixed_evidence',
    'stale_evidence',
    'cross_thread',
    'cross_pack',
    'blocked',
  };

  static const Set<String> allowedRelationStateValues = {
    'one_moment',
    'two_related',
    'two_unrelated',
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
    bool? hasRealTimeline,
    bool? hasPhrase,
    bool? hasActionPhrase,
    bool? hasConfirmedRepeat,
    String? comparisonState,
    int? phraseCount,
    bool? hasStrongEvidence,
    int? milestoneCount,
    String? relationState,
    String? answer,
    String? source,
    String? stage,
    String? cardType,
    String? reason,
    String? plan,
    String? ref,
    String? method,
    bool? enabled,
    String? errorType,
    String? lineId,
    String? relevance,
    String? connectionMode,
    String? memoryScope,
    String? entryMemoryMode,
    String? threadScope,
    String? scoreBand,
    int? recordCount,
    String? authorityState,
    String? influenceLevel,
    String? reasonId,
    String? filterType,
    String? resultCountBucket,
    String? collectionCountBucket,
    String? actionType,
    String? format,
    String? selectionCountBucket,
    String? reliabilityState,
    String? packCountBucket,
    String? decisionId,
    String? suggestedAction,
    String? currentIntent,
    String? relevanceBand,
    String? priorityBand,
    String? status,
    String? actionItemCountBucket,
    String? entryAboutness,
    String? surfacingMode,
    String? surfaceType,
    String? preservationSource,
    String? factType,
    String? factCountBucket,
    String? shareType,
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
      if (hasRealTimeline != null)
        'has_real_timeline': hasRealTimeline ? 1 : 0,
      if (hasPhrase != null) 'has_phrase': hasPhrase ? 1 : 0,
      if (hasActionPhrase != null)
        'has_action_phrase': hasActionPhrase ? 1 : 0,
      if (hasConfirmedRepeat != null)
        'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (comparisonState != null && _safeValue.hasMatch(comparisonState))
        'comparison_state': comparisonState,
      if (answer != null && _safeValue.hasMatch(answer)) 'answer': answer,
      if (phraseCount != null) 'phrase_count': phraseCount,
      if (hasStrongEvidence != null)
        'has_strong_evidence': hasStrongEvidence ? 1 : 0,
      if (milestoneCount != null) 'milestone_count': milestoneCount,
      if (relationState != null &&
          allowedRelationStateValues.contains(relationState))
        'relation_state': relationState,
      if (source != null && _safeValue.hasMatch(source)) 'source': source,
      if (stage != null && _safeValue.hasMatch(stage)) 'stage': stage,
      if (cardType != null && _safeValue.hasMatch(cardType))
        'card_type': cardType,
      if (reason != null && _safeValue.hasMatch(reason)) 'reason': reason,
      if (plan != null && _safeValue.hasMatch(plan)) 'plan': plan,
      if (ref != null && _safeValue.hasMatch(ref)) 'ref': ref,
      if (method != null && _safeValue.hasMatch(method)) 'method': method,
      if (enabled != null) 'enabled': enabled ? 'true' : 'false',
      if (errorType != null && _safeValue.hasMatch(errorType))
        'error_type': errorType,
      if (lineId != null && _safeValue.hasMatch(lineId)) 'line_id': lineId,
      if (relevance != null && allowedRelevanceValues.contains(relevance))
        'relevance': relevance,
      if (connectionMode != null &&
          allowedConnectionModeValues.contains(connectionMode))
        'connection_mode': connectionMode,
      if (memoryScope != null && allowedMemoryScopeValues.contains(memoryScope))
        'memory_scope': memoryScope,
      if (entryMemoryMode != null &&
          allowedEntryMemoryModeValues.contains(entryMemoryMode))
        'entry_memory_mode': entryMemoryMode,
      if (threadScope != null && allowedThreadScopeValues.contains(threadScope))
        'thread_scope': threadScope,
      if (scoreBand != null && allowedScoreBandValues.contains(scoreBand))
        'score_band': scoreBand,
      if (recordCount != null) 'record_count': recordCount,
      if (authorityState != null &&
          allowedAuthorityStateValues.contains(authorityState))
        'authority_state': authorityState,
      if (influenceLevel != null &&
          allowedInfluenceLevelValues.contains(influenceLevel))
        'influence_level': influenceLevel,
      if (reasonId != null && allowedReasonIdValues.contains(reasonId))
        'reason_id': reasonId,
      if (filterType != null && allowedFilterTypeValues.contains(filterType))
        'filter_type': filterType,
      if (resultCountBucket != null &&
          allowedResultCountBucketValues.contains(resultCountBucket))
        'result_count_bucket': resultCountBucket,
      if (collectionCountBucket != null &&
          allowedCollectionCountBucketValues.contains(collectionCountBucket))
        'collection_count_bucket': collectionCountBucket,
      if (actionType != null && allowedActionTypeValues.contains(actionType))
        'action_type': actionType,
      if (format != null && allowedFormatValues.contains(format))
        'format': format,
      if (selectionCountBucket != null &&
          allowedSelectionCountBucketValues.contains(selectionCountBucket))
        'selection_count_bucket': selectionCountBucket,
      if (reliabilityState != null &&
          allowedReliabilityStateValues.contains(reliabilityState))
        'reliability_state': reliabilityState,
      if (packCountBucket != null &&
          allowedResultCountBucketValues.contains(packCountBucket))
        'pack_count_bucket': packCountBucket,
      if (decisionId != null && allowedDecisionIdValues.contains(decisionId))
        'decision_id': decisionId,
      if (suggestedAction != null &&
          allowedSuggestedActionValues.contains(suggestedAction))
        'suggested_action': suggestedAction,
      if (currentIntent != null &&
          allowedCurrentIntentValues.contains(currentIntent))
        'current_intent': currentIntent,
      if (relevanceBand != null &&
          allowedRelevanceBandValues.contains(relevanceBand))
        'relevance_band': relevanceBand,
      if (priorityBand != null &&
          allowedPriorityBandValues.contains(priorityBand))
        'priority_band': priorityBand,
      if (status != null &&
          (allowedActionItemStatusValues.contains(status) ||
              allowedShareStatusValues.contains(status)))
        'status': status,
      if (actionItemCountBucket != null &&
          allowedResultCountBucketValues.contains(actionItemCountBucket))
        'action_item_count_bucket': actionItemCountBucket,
      if (entryAboutness != null &&
          allowedEntryAboutnessValues.contains(entryAboutness))
        'entry_aboutness': entryAboutness,
      if (surfacingMode != null &&
          allowedSurfacingModeValues.contains(surfacingMode))
        'surfacing_mode': surfacingMode,
      if (surfaceType != null && allowedSurfaceTypeValues.contains(surfaceType))
        'surface_type': surfaceType,
      if (preservationSource != null &&
          allowedPreservationSourceValues.contains(preservationSource))
        'preservation_source': preservationSource,
      if (factType != null && allowedFactTypeValues.contains(factType))
        'fact_type': factType,
      if (factCountBucket != null &&
          allowedResultCountBucketValues.contains(factCountBucket))
        'fact_count_bucket': factCountBucket,
      if (shareType != null && allowedShareTypeValues.contains(shareType))
        'share_type': shareType,
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
