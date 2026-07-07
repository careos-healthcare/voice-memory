import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../audio/recording_service.dart';
import '../services/app_services.dart';
import '../services/capture_pipeline_service.dart';
import '../services/record_pipeline_log.dart';
import '../services/capture_save_messages.dart';
import '../design/archive_mobile_typography.dart';
import '../theme/app_colors.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/archive_evidence/archive_entry_signal_guard.dart';
import '../features/archive_evidence/archive_evidence_quality_gate.dart';
import '../features/archive_evidence/comparable_evidence_text.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../features/activation/second_session_payoff.dart';
import '../features/activation/third_entry_belief_payoff.dart';
import '../features/activation/belief_update_payoff.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/activation/day_two_return_loop_payoff.dart';
import '../features/voice_capture/voice_capture_post_save.dart';
import '../features/voice_capture/voice_capture_quality.dart';
import '../features/voice_capture/microphone_permission_copy.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/voice_capture/microphone_permission_state.dart';
import '../features/memory/memory_scope_store.dart';
import '../features/memory/curated_memory_marker.dart';
import '../features/memory/keep_exact_details.dart';
import '../features/memory/treat_as_new.dart';
import '../widgets/memory/entry_options_section.dart';
import '../widgets/memory/not_about_me_receipt.dart';
import '../widgets/memory/do_not_surface_receipt.dart';
import '../widgets/memory/sensitive_surfacing_receipt.dart';
import '../features/memory/entry_aboutness.dart';
import '../features/memory/memory_surfacing_mode.dart';
import '../widgets/memory/clean_slate_prompt_section.dart';
import '../features/memory/clean_slate_prompt_store.dart';
import '../widgets/memory/keep_exact_details_control.dart';
import '../widgets/memory/curated_memory_receipt.dart';
import '../widgets/memory/treat_as_new_control.dart';
import '../features/archive_movement/archive_movement.dart';
import '../features/archive_prompt/archive_prompt_engine.dart';
import '../product/belief_product_copy.dart';
import '../product/consumer_copy_guard.dart';
import '../product/consumer_ui_copy.dart';
import '../config/trial_mode.dart';
import '../features/trial/hook_rescue_decision_engine.dart';
import '../features/trial/hook_rescue_decision_model.dart';
import '../features/trial/trial_summary_engine.dart';
import '../config/archive_me_demo_state.dart';
import '../config/creator_demo_mode.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../features/demo/archive_me_demo_archive.dart';
import '../features/tomorrow_return/return_comparison_coordinator.dart';
import '../features/tomorrow_return/return_comparison_model.dart';
import '../features/tomorrow_return/return_retention_coordinator.dart';
import '../features/tomorrow_return/return_streak_model.dart';
import '../features/tomorrow_return/tomorrow_return_loop_coordinator.dart';
import '../features/tomorrow_return/tomorrow_return_loop_models.dart';
import '../features/activation/activation_tracker.dart';
import '../features/feedback/archive_feedback_coordinator.dart';
import '../features/feedback/archive_feedback_model.dart';
import '../features/input_quality/input_quality_engine.dart';
import '../features/perspective/kinder_angle_engine.dart';
import '../features/perspective/kinder_angle_model.dart';
import '../features/quick_help/quick_help_model.dart';
import '../features/moments/key_moment_coordinator.dart';
import '../features/moments/key_moment_model.dart';
import '../features/input_quality/input_quality_model.dart';
import '../features/input_quality/input_quality_store.dart';
import '../features/language/language_detection_engine.dart';
import '../features/language/language_model.dart';
import '../features/language/reflection_language_store.dart';
import '../widgets/language/language_indicator_chip.dart';
import '../features/activation/first_loop_activation_coordinator.dart';
import '../features/activation/first_loop_activation_model.dart';
import '../features/activation/return_day_friction_coordinator.dart';
import '../features/activation/first_three_journey_coordinator.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/activation/first_three_journey_model.dart';
import '../features/activation/first_three_session_gates.dart';
import '../features/activation/paywall_timing_gates.dart';
import '../features/first_session/first_session_coordinator.dart';
import '../features/first_session/first_session_pattern_model.dart';
import '../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../features/tomorrow_return/active_pattern_thread_model.dart';
import '../features/pattern_memory/habit_proof_model.dart';
import '../features/pattern_memory/pattern_memory_coordinator.dart';
import '../features/pattern_memory/pattern_memory_model.dart';
import '../features/pattern_memory/pattern_next_action_model.dart';
import '../features/pattern_memory/pattern_progress_model.dart';
import '../features/pattern_memory/pattern_share_recap_model.dart';
import '../features/pattern_memory/pattern_share_service.dart';
import '../features/pattern_memory/weekly_pattern_recap_model.dart';
import '../features/routine/routine_anchor_model.dart';
import '../features/routine/routine_anchor_store.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../features/tomorrow_return/watch_for_coordinator.dart';
import '../features/tomorrow_return/watch_for_model.dart';
import '../features/archive_beliefs/archive_beliefs_presenter.dart';
import '../widgets/potential_signals_card.dart';
import '../widgets/patterns/return_comparison_card.dart';
import '../widgets/patterns/return_streak_card.dart';
import '../widgets/routine/routine_anchor_chooser.dart';
import '../widgets/return_ritual_card.dart';
import '../widgets/archive_return_changes_card.dart';
import '../widgets/archive_depth_card.dart';
import '../features/archive_depth/archive_depth_engine.dart';
import '../features/archive_depth/archive_depth_gates.dart';
import '../features/return_changes/archive_return_changes_engine.dart';
import '../features/return_changes/archive_return_changes_gates.dart';
import '../features/return_changes/archive_return_changes_store.dart';
import '../features/return_changes/archive_return_snapshot.dart';
import '../widgets/record/moment_quality_feedback_card.dart';
import '../features/moment_quality/moment_quality_feedback_engine.dart';
import '../widgets/record/post_save_moment_detail_sheet.dart';
import '../features/moment_quality/post_save_moment_detail_copy.dart';
import '../features/moment_quality/post_save_moment_detail_model.dart';
import '../widgets/record/tomorrow_commitment_card.dart';
import '../widgets/record/tomorrow_return_card.dart';
import '../widgets/record/active_pattern_thread_prompt_card.dart';
import '../widgets/activation/first_three_journey_card.dart';
import '../widgets/record/first_reflection_result_card.dart';
import '../widgets/record/post_save_insight_choice_card.dart';
import '../widgets/record/second_session_comparison_card.dart';
import '../widgets/record/pattern_hypothesis_card.dart';
import '../features/signal_journey/signal_journey_coordinator.dart';
import '../features/signal_journey/signal_journey_model.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../features/signal_review/signal_review_model.dart';
import '../features/signal_review/signal_review_navigation.dart';
import '../widgets/signal/archive_watching_card.dart';
import '../widgets/signal/signal_journey_card.dart';
import '../widgets/signal/signal_journey_completion_card.dart';
import '../widgets/signal/signal_review_card.dart';
import '../features/retention/return_tomorrow_cue_engine.dart';
import '../features/retention/first_week_progress_engine.dart';
import '../features/three_day_challenge/three_day_challenge_engine.dart';
import '../features/return_day/return_day_flow_copy.dart';
import '../features/return_day/return_day_flow_engine.dart';
import '../features/return_day/return_day_flow_store.dart';
import '../features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import '../features/come_back_tomorrow/come_back_tomorrow_v2_engine.dart';
import '../features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../widgets/record/come_back_tomorrow_card.dart';
import '../features/quiet_signal/quiet_signal_engine.dart';
import '../features/beta_test_script/beta_test_script_engine.dart';
import '../features/beta_test_script/beta_test_script_store.dart';
import '../widgets/account/beta_test_script_sheet.dart';
import '../widgets/record/beta_test_script_card.dart';
import '../widgets/record/quiet_signal_record_card.dart';
import '../widgets/account/beta_feedback_sheet.dart';
import '../features/retention/second_session_signal_engine.dart';
import '../features/retention/second_session_signal_model.dart';
import '../features/retention/pattern_hypothesis_engine.dart';
import '../features/retention/pattern_hypothesis_model.dart';
import '../features/post_save_insight/selected_signal_coordinator.dart';
import '../features/post_save_insight/signal_feedback_store.dart';
import '../features/post_save_insight/signal_feedback_coordinator.dart';
import '../features/post_save_insight/signal_feedback_model.dart';
import '../features/post_save_insight/selected_signal_model.dart';
import '../features/signal_archive/signal_archive_coordinator.dart';
import '../features/signal_archive/signal_archive_snapshot.dart';
import '../features/objective/current_objective_model.dart';
import '../features/objective/current_objective_snapshot_store.dart';
import '../widgets/record/input_quality_coach_card.dart';
import '../widgets/onboarding/archive_memory_demo_card.dart';
import '../widgets/record/first_loop_start_card.dart';
import '../widgets/record/return_day_closed_card.dart';
import '../widgets/record/habit_proof_card.dart';
import '../widgets/record/weekly_pattern_recap_card.dart';
import '../widgets/record/pattern_next_action_card.dart';
import '../widgets/record/check_in_completed_card.dart';
import '../widgets/quick_help/quick_help_button.dart';
import '../widgets/quick_help/quick_help_sheet.dart';
import '../widgets/record/kinder_angle_card.dart';
import '../widgets/record/perspective_shift_card.dart';
import '../widgets/record/result_next_check_card.dart';
import '../widgets/record/pattern_memory_after_save_card.dart';
import '../widgets/record/pattern_progress_after_save_card.dart';
import '../widgets/patterns/missed_check_in_reason_prompt.dart';
import '../widgets/record/tomorrow_check_in_due_card.dart';
import '../widgets/record/todays_watch_for_card.dart';
import '../widgets/record/watch_for_tomorrow_card.dart';
import '../widgets/patterns/active_pattern_thread_card.dart';
import '../widgets/patterns/watch_for_result_card.dart';
import '../widgets/record/early_first_signal_card.dart';
import '../features/low_evidence/low_evidence_engine.dart';
import '../widgets/record/low_evidence_guidance_card.dart';
import '../features/archive_history/archive_history_engine.dart';
import '../widgets/archive_history/archive_history_sheet.dart';
import '../widgets/record/pending_transcript_recovery_sheet.dart';
import '../features/record_capture_modes/record_capture_mode_engine.dart';
import '../features/record_capture_modes/record_capture_mode_model.dart';
import '../widgets/record/navigate_to_capture_mode.dart';
import '../widgets/record/record_capture_modes_card.dart';
import '../widgets/record/first_session_onboarding_card.dart';
import '../widgets/record/daily_archive_memory_card.dart';
import '../widgets/record/first_use_wording_helper_card.dart';
import '../widgets/record/correct_transcript_sheet.dart';
import '../features/trust/pending_transcript_recovery_copy.dart';
import '../features/transcript_correction/transcript_correction_copy.dart';
import '../features/transcript_correction/transcript_correction_gate.dart';
import '../widgets/record/post_save_return_handoff_card.dart';
import '../widgets/record/first_week_progress_line.dart';
import '../widgets/record/three_day_challenge_card.dart';
import '../widgets/record/return_tomorrow_cue_card.dart';
import '../widgets/record/return_day_flow_card.dart';
import '../widgets/record/first_proof_action_loop_card.dart';
import '../widgets/record/first_proof_payoff_card.dart';
import '../widgets/record/first_proof_truth_card.dart';
import '../widgets/record/first_week_loop_card.dart';
import '../widgets/record/return_check_payoff_card.dart';
import '../widgets/record/confirmed_repeat_thought_map_card.dart';
import '../widgets/record/confirmed_repeat_why_matters_card.dart';
import '../widgets/patterns/helpful_action_appeared_card.dart';
import '../widgets/record/positive_reinforcement_card.dart';
import '../widgets/record/archive_summary_card.dart';
import '../widgets/record/daily_return_reason_card.dart';
import '../features/weekly_review/weekly_archive_review_engine.dart'
    as weeklyReviewSurface;
import '../features/weekly_review/weekly_archive_review_model.dart';
import '../widgets/weekly_review/weekly_archive_review_card.dart'
    as weeklyReviewSurface;
import '../widgets/weekly_review/weekly_archive_review_sheet.dart';
import '../features/pattern_naming/pattern_name_engine.dart';
import '../features/pattern_naming/pattern_name_store.dart';
import '../features/helped_tracking/helped_tracking_engine.dart';
import '../features/helped_tracking/helped_tracking_store.dart';
import '../features/entry_importance/entry_importance_store.dart';
import '../widgets/record/helped_tracking_card.dart';
import '../widgets/patterns/pattern_name_confirmation_card.dart';
import '../widgets/record/confirmed_repeat_trigger_payoff_card.dart';
import '../widgets/record/confirmed_repeat_change_notice_card.dart';
import '../widgets/record/confirmed_repeat_helpful_action_payoff_card.dart';
import '../widgets/record/early_evidence_timeline_card.dart';
import '../widgets/record/early_archive_return_reminder_card.dart';
import '../widgets/record/consumer_record_prompts_section.dart';
import '../features/record/record_stack_policy.dart';
import '../features/record/daily_mirror_engine.dart';
import '../features/record/daily_mirror_model.dart';
import '../features/early_archive/early_first_signal_engine.dart';
import '../features/next_action/next_best_action_engine.dart';
import '../features/next_action/next_best_action_gates.dart';
import '../features/next_action/next_best_action_model.dart';
import '../widgets/next_action/next_best_action_line.dart';
import '../features/early_archive/post_save_return_handoff_engine.dart';
import '../features/early_archive/post_save_return_handoff_gates.dart';
import '../features/first_proof_action_loop/first_proof_action_loop_engine.dart';
import '../features/first_proof_action_loop/first_proof_action_loop_gates.dart';
import '../features/pattern_correction/pattern_correction_gates.dart';
import '../features/first_proof_payoff/first_proof_payoff_engine.dart';
import '../features/first_proof_payoff/first_proof_payoff_gates.dart';
import '../features/first_proof_truth/first_proof_truth_gates.dart';
import '../features/first_proof_truth/first_proof_truth_store.dart';
import '../features/archive_controls/archive_exclusion_engine.dart';
import '../widgets/archive_controls/archive_pattern_exclusion_actions.dart';
import '../features/pattern_naming/pattern_name_analytics.dart';
import '../widgets/patterns/rename_pattern_sheet.dart';
import '../features/pattern_detail/pattern_detail_engine.dart';
import '../features/pattern_detail/pattern_detail_model.dart';
import '../features/share_card/share_card_builder.dart';
import '../widgets/patterns/pattern_detail_sheet.dart';
import '../widgets/patterns/pattern_correction_sheet.dart';
import '../features/retention/return_tomorrow_cue_engine.dart';
import '../features/archive_evidence/archive_evidence_guard.dart';
import '../features/early_archive/first_week_loop_engine.dart';
import '../features/early_archive/first_week_loop_gates.dart';
import '../features/early_archive/return_check_payoff_engine.dart';
import '../features/early_archive/return_check_payoff_gates.dart';
import '../features/what_changed/what_changed_v2_engine.dart';
import '../features/pattern_confidence/pattern_confidence_engine.dart';
import '../features/what_changed/what_changed_v2_store.dart';
import '../features/current_relevance/current_relevance_engine.dart';
import '../features/current_relevance/current_relevance_store.dart';
import '../features/correction_memory/correction_memory_engine.dart';
import '../features/correction_memory/correction_memory_store.dart';
import '../features/evidence_weighting/evidence_weighting_engine.dart';
import '../features/proof_specificity/proof_specificity_engine.dart';
import '../features/proof_specificity_boost/proof_specificity_boost_engine.dart';
import '../features/proof_specificity_boost/proof_specificity_boost_model.dart';
import '../features/not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../features/proof_quality_response/proof_quality_response_engine.dart';
import '../features/proof_quality_response/proof_quality_response_model.dart';
import '../features/pro_moment_timing/pro_moment_timing_engine.dart';
import '../features/pro_moment_timing/pro_moment_timing_model.dart';
import '../features/present_day_relevance/present_day_relevance_engine.dart';
import '../features/timeline_positioning/timeline_positioning_engine.dart';
import '../widgets/patterns/current_relevance_card.dart';
import '../widgets/patterns/correction_memory_card.dart';
import '../widgets/patterns/evidence_weighting_card.dart';
import '../widgets/patterns/proof_specificity_card.dart';
import '../widgets/patterns/proof_specificity_boost_card.dart';
import '../widgets/patterns/not_relevant_recovery_card.dart';
import '../widgets/patterns/proof_quality_response_card.dart';
import '../features/pattern_confidence/pattern_confidence_engine.dart';
import '../widgets/patterns/pattern_confidence_card.dart';
import '../widgets/patterns/present_day_relevance_card.dart';
import '../widgets/patterns/timeline_positioning_card.dart';
import '../features/open_capture/open_capture_engine.dart';
import '../features/low_friction_return/low_friction_return_engine.dart';
import '../features/first_moment_capture/first_moment_capture_engine.dart';
import '../features/second_moment_return/second_moment_return_engine.dart';
import '../features/second_moment_return/second_moment_return_store.dart';
import '../features/beta_today_summary/beta_today_summary_engine.dart';
import '../features/what_to_notice_next/what_to_notice_next_engine.dart';
import '../features/beta_tester_report/beta_tester_report_engine.dart';
import '../features/surface_priority/surface_priority_analytics.dart';
import '../features/surface_priority/surface_priority_engine.dart';
import '../features/surface_priority/surface_priority_model.dart';
import '../features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import '../features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import '../features/shareable_proof/shareable_proof_engine.dart';
import '../features/shareable_proof/shareable_proof_model.dart';
import '../widgets/record/capture_freedom_line.dart';
import '../widgets/record/open_capture_prompt_chips.dart';
import '../widgets/record/low_friction_return_card.dart';
import '../widgets/record/first_moment_capture_card.dart';
import '../widgets/record/second_moment_return_card.dart';
import '../widgets/beta/beta_today_summary_card.dart';
import '../widgets/record/what_to_notice_next_card.dart';
import '../widgets/beta/beta_tester_report_card.dart';
import '../widgets/share/shareable_proof_card.dart';
import '../widgets/common/surface_priority_debug_badge.dart';
import '../widgets/patterns/archive_timeline_spine_card.dart';
import '../widgets/patterns/timeline_proof_moment_card.dart';
import '../widgets/record/what_changed_v2_card.dart';
import '../features/early_archive/early_first_signal_copy.dart';
import '../features/early_archive/early_archive_proof_analytics.dart';
import '../features/early_archive/early_evidence_timeline_engine.dart';
import '../features/early_archive/archive_proof_surface_layout.dart';
import '../features/early_archive/record_proof_stack_policy.dart';
import '../features/early_archive/early_archive_return_reminder_gates.dart';
import '../features/early_archive/early_archive_return_reminder_store.dart';
import '../features/early_archive/early_evidence_milestone_store.dart';
import '../features/early_archive/confirmed_repeat_trigger_capture.dart';
import '../features/early_archive/confirmed_repeat_thought_map_analytics.dart';
import '../features/early_archive/confirmed_repeat_thought_map_engine.dart';
import '../features/early_archive/confirmed_repeat_thought_map_gates.dart';
import '../features/early_archive/confirmed_repeat_thought_map_models.dart';
import '../features/early_archive/confirmed_repeat_thought_map_store.dart';
import '../features/early_archive/confirmed_repeat_why_matters_gates.dart';
import '../features/early_archive/confirmed_repeat_why_matters_store.dart';
import '../features/early_archive/positive_pattern_engine.dart';
import '../features/early_archive/helpful_action_appeared_engine.dart';
import '../features/early_archive/helpful_action_appeared_gates.dart';
import '../features/early_archive/positive_reinforcement_analytics.dart';
import '../features/early_archive/positive_reinforcement_engine.dart';
import '../features/early_archive/positive_reinforcement_gates.dart';
import '../features/early_archive/private_archive_report_engine.dart';
import '../features/early_archive/private_archive_report_gates.dart';
import '../features/early_archive/archive_summary_engine.dart';
import '../features/archive_proof/archive_belief_surface.dart';
import '../features/archive_proof/archive_current_belief_gates.dart';
import '../widgets/patterns/archive_belief_surface_card.dart';
import '../features/early_archive/archive_summary_gates.dart';
import '../features/early_archive/archive_summary_model.dart';
import '../features/early_archive/archive_watching_engine.dart';
import '../features/early_archive/archive_watching_gates.dart';
import '../features/early_archive/daily_return_reason_analytics.dart';
import '../features/early_archive/daily_return_reason_engine.dart';
import '../features/early_archive/daily_return_reason_gates.dart';
import '../features/early_archive/daily_return_reason_model.dart';
import '../features/early_archive/weekly_archive_review_analytics.dart';
import '../features/early_archive/confirmed_repeat_helpful_action_capture.dart';
import '../features/record/record_empty_archive_gates.dart';
import '../features/return_ritual/return_ritual_gates.dart';
import '../features/acquisition/audience_wedge_model.dart';
import '../features/acquisition/audience_wedge_store.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../features/quality/first_insight_specificity_store.dart';
import '../widgets/loop_mode/loop_mode_progress_card.dart';
import '../widgets/record/loop_mode_first_handoff_card.dart';
import '../widgets/before_you_say_yes_card.dart';
import '../features/capacity_loop/before_yes_copy.dart';
import '../features/capacity_loop/before_yes_engine.dart';
import '../features/capacity_loop/low_effort_yes_capture_copy.dart';
import '../features/capacity_loop/capacity_boundary_response_copy.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../product/loop_mode_copy.dart';
import '../features/capacity_loop/capacity_loop_gates.dart';
import '../features/capacity_loop/capacity_return_trigger_engine.dart';
import '../features/capacity_loop/capacity_return_trigger_models.dart';
import '../features/capacity_loop/capacity_three_moment_engine.dart';
import '../features/capacity_loop/low_effort_yes_capture_engine.dart';
import '../features/capacity_loop/low_effort_yes_capture_models.dart';
import '../widgets/low_effort_yes_capture_card.dart';
import '../widgets/capacity_return_trigger_card.dart';
import '../features/retention/next_evidence_reminder_service.dart';
import '../features/retention/reminder_pre_prompt_coordinator.dart';
import '../features/retention/return_reason_capture_coordinator.dart';
import '../features/retention/return_day_journey_engine.dart';
import '../features/objective/current_objective_engine.dart';
import '../features/objective/current_objective_model.dart';
import '../features/retention/retention_reminder_coordinator.dart';
import '../features/retention/retention_state_engine.dart';
import '../features/retention/retention_state_model.dart';
import '../features/tomorrow_return/compelling_check_engine.dart';
import '../widgets/objective/current_objective_card.dart';
import '../widgets/retention/retention_state_card.dart';
import '../widgets/record/first_recording_handoff_card.dart';
import '../widgets/retention/reminder_pre_prompt_sheet.dart';
import '../widgets/signal/return_day_journey_card.dart';
import '../widgets/trial/trial_first_moment_card.dart';
import '../dev/visual_audit_overrides.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../features/archive_evolution/archive_evolution_coordinator.dart';
import '../features/archive_evolution/archive_evolution_models.dart';
import '../features/instant_reflection/instant_reflection_response.dart';
import '../features/instant_reflection/instant_reflection_response_engine.dart';
import '../widgets/indigo_capture_waveform.dart';
import '../features/daily_discoveries/daily_discovery_engine.dart';
import '../features/daily_discoveries/daily_discovery_models.dart';
import '../features/daily_discoveries/daily_discovery_store.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/product_analytics.dart';
import '../features/pressure_retention/pressure_return_trigger_store.dart';
import '../widgets/capture_entry_actions.dart';
import '../widgets/record/entry_direction_starters.dart';
import '../billing/purchase_intent_return_cue.dart';
import '../features/referral/invite_attribution.dart';
import '../features/referral/invite_funnel_metrics.dart';
import '../features/referral/invited_day_two_return.dart';
import '../features/referral/invited_user_welcome.dart';
import '../widgets/referral/invited_day_two_return_card.dart';
import '../widgets/referral/invited_user_welcome_card.dart';
import '../features/first_session/day_seven_continuity_loop.dart';
import '../features/first_session/day_two_reminder.dart';
import '../features/first_session/day_two_return_preview.dart';
import '../features/first_session/first_recording_sample.dart';
import '../features/first_session/two_day_activation_engine.dart';
import '../widgets/first_session/day_seven_continuity_card.dart';
import '../widgets/first_session/day_two_reminder_card.dart';
import '../widgets/first_session/day_two_return_preview_card.dart';
import '../widgets/first_session/first_recording_sample_card.dart';
import '../widgets/first_session/first_save_rescue_card.dart';
import '../widgets/first_session/first_session_explanation_card.dart';
import '../widgets/first_session/two_day_activation_card.dart';
import '../widgets/pressure_retention/pressure_return_trigger_reminder.dart';
import '../billing/archive_entitlement_reader.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../billing/suggestion_attribution_event.dart';
import '../billing/suggestion_attribution_store.dart';
import '../features/pressure_retention/archive_proof_counter_engine.dart';
import '../features/pressure_retention/archive_proof_counter_model.dart';
import '../features/pressure_retention/daily_return_suggestion_engine.dart';
import '../features/pressure_retention/daily_return_suggestion_model.dart';
import '../features/pressure_retention/done_for_today_receipt_engine.dart';
import '../features/pressure_retention/done_for_today_receipt_model.dart';
import '../features/pressure_retention/low_effort_check_in_engine.dart';
import '../features/pressure_retention/low_effort_check_in_model.dart';
import '../features/pressure_retention/one_small_recording_engine.dart';
import '../features/pressure_retention/one_small_recording_model.dart';
import '../features/pressure_retention/personal_return_prompt_engine.dart';
import '../features/pressure_retention/pressure_context.dart';
import '../billing/value_moment_paywall_trigger.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../features/pressure_retention/personal_return_prompt_model.dart';
import '../features/pressure_retention/pressure_check_in_record.dart';
import '../features/pressure_retention/pressure_check_in_store.dart';
import '../features/pressure_retention/start_here_save_receipt_engine.dart';
import '../features/pressure_retention/start_here_save_receipt_model.dart';
import '../features/pressure_retention/thread_return_evidence_engine.dart';
import '../features/pressure_retention/weekly_thread_review_engine.dart';
import '../widgets/record/start_here_save_receipt_card.dart';
import '../widgets/record/daily_return_suggestions_card.dart';
import '../widgets/billing/purchase_intent_return_cue_card.dart';
import '../widgets/billing/value_moment_pro_bridge.dart';
import '../widgets/pressure_retention/archive_proof_counter_card.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';
import '../widgets/record/done_for_today_receipt_card.dart';
import '../widgets/record/belief_update_payoff_card.dart';
import '../widgets/record/day_two_return_loop_card.dart';
import '../features/post_save/post_save_archive_hierarchy.dart';
import '../features/post_save/post_save_completion_copy_gates.dart';
import '../features/record/record_home_surface_policy.dart';
import '../widgets/record/post_save_focused_actions_bar.dart';
import '../widgets/record/post_save_recorded_summary_card.dart';
import '../widgets/record/post_save_listening_card.dart';
import '../widgets/record/capture_context_tag_card.dart';
import '../widgets/record/low_effort_check_in_card.dart';
import '../widgets/record/one_small_recording_card.dart';
import '../widgets/record/daily_mirror_record_card.dart';
import '../widgets/record/microphone_permission_blocked_panel.dart';
import '../widgets/record/record_first_use_capture_section.dart';
import '../widgets/record/record_top_archive_promise_hero.dart';
import '../widgets/record/record_screen_close_button.dart';
import '../widgets/record/record_first_run_privacy_reassurance.dart';
import '../features/onboarding/archive_journey_explainer_gates.dart';
import '../features/onboarding/first_session_onboarding_store.dart';
import '../features/daily_archive_memory/daily_archive_memory_engine.dart';
import '../features/daily_archive_memory/daily_archive_memory_model.dart';
import '../features/first_use_wording/first_use_wording_model.dart';
import '../features/onboarding/record_return_pro_state.dart';
import '../features/onboarding/record_return_pro_store.dart';
import '../features/memory/memory_scope.dart';
import '../features/memory/memory_scope_policy.dart';
import '../features/retention/repeat_recording_nudge_state.dart';
import '../features/retention/repeat_recording_nudge_store.dart';
import '../features/aha/aha_moment_candidate.dart';
import '../features/aha/aha_moment_engine.dart';
import '../features/aha/aha_moment_store.dart';
import '../widgets/aha/first_aha_moment_card.dart';
import '../features/trust/archive_trust_receipt.dart';
import '../widgets/trust/archive_private_receipt_card.dart';
import '../widgets/trust/pro_value_clarity_card.dart';
import '../widgets/share/aha_proof_share_card.dart';
import '../features/trust/aha_proof_share_eligibility.dart';
import '../widgets/retention/day2_return_reason_card.dart';
import '../widgets/retention/second_entry_nudge_card.dart';
import '../widgets/retention/tiny_record_again_cta.dart';
import '../widgets/onboarding/change_starts_card.dart';
import '../features/archive_proof/archive_demo_preview_resolver.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../features/activation/next_moment_prompt.dart';
import '../widgets/record/next_moment_prompt_card.dart';
import '../features/todays_question/todays_question_copy.dart';
import '../features/todays_question/todays_question_engine.dart';
import '../features/todays_question/todays_question_models.dart';
import '../widgets/record/todays_one_question_card.dart';
import '../screens/todays_one_question_screen.dart';
import '../features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import '../features/daily_archive_exercise/daily_archive_exercise_engine.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta/beta_activation_loop_tracker.dart';
import '../features/beta/tester_mission_engine.dart';
import '../features/beta/tester_mission_gates.dart';
import '../features/beta/tester_mission_store.dart';
import '../features/beta/confirmed_repeat_beta_feedback_gates.dart';
import '../features/beta/confirmed_repeat_beta_feedback_store.dart';
import '../features/beta/core_value_feedback_gates.dart';
import '../features/beta/core_value_feedback_model.dart';
import '../features/beta/core_value_feedback_store.dart';
import '../features/beta_proof_feedback/beta_proof_feedback_engine.dart';
import '../features/beta_proof_feedback/beta_proof_feedback_model.dart';
import '../features/beta_proof_feedback/beta_proof_feedback_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/repeat_return_check/repeat_return_check_engine.dart';
import '../features/repeat_return_check/repeat_return_check_store.dart';
import '../features/repeat_return_check/repeat_return_check_trend.dart';
import '../features/repeat_return_check/pattern_changed_analytics.dart';
import '../features/repeat_return_check/pattern_changed_engine.dart';
import '../features/repeat_return_check/pattern_changed_gates.dart';
import '../features/repeat_return_check/pattern_changed_store.dart';
import '../features/trust/capture_recovery_gates.dart';
import '../widgets/record/capture_recovery_hint_strip.dart';
import '../widgets/beta/confirmed_repeat_beta_feedback_card.dart';
import '../widgets/beta/core_value_feedback_card.dart';
import '../widgets/beta/beta_proof_feedback_row.dart';
import '../widgets/beta/tester_mission_card.dart';
import '../widgets/record/repeat_return_check_card.dart';
import '../widgets/record/repeat_return_check_change_proof_card.dart';
import '../widgets/record/pattern_changed_card.dart';
import '../widgets/record/private_archive_report_card.dart';
import '../widgets/record/daily_archive_exercise_record_card.dart';
import '../features/activation/returning_user_today.dart';
import '../widgets/record/returning_user_today_card.dart';
import '../features/activation/capture_context_tags.dart';
import '../widgets/onboarding/first_save_evidence_card.dart';
import '../widgets/record/first_entry_saved_receipt_card.dart';
import '../widgets/patterns/archive_demo_preview_card.dart';
import '../features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../features/pro_evidence_value/pro_evidence_value_engine.dart';
import '../features/pro_evidence_value/pro_evidence_value_model.dart';
import '../features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import '../features/monthly_private_report/monthly_private_report_engine.dart';
import '../features/monthly_private_report/monthly_private_report_model.dart';
import '../features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import '../features/pro_lock_moment/pro_lock_moment_engine.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import '../widgets/pro/pro_evidence_value_card.dart';
import '../widgets/pro/monthly_private_report_preview_card.dart';
import '../widgets/pro/pro_lock_moment_card.dart';
import '../widgets/beta/beta_feedback_intelligence_card.dart';
import '../widgets/onboarding/pro_archive_continuity_card.dart';
import '../widgets/onboarding/record_once_intro_card.dart';
import '../widgets/onboarding/tomorrow_return_cue_card.dart';
import '../record/example_prompt_visibility.dart';
import '../record/record_screen_framing_copy.dart';

import '../features/voice_capture/record_microphone_permission_ui.dart';
import '../features/voice_capture/record_cta_policy.dart';

export '../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

void _recordPermissionUiLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.logPrefix} $message');
}

void _recordCtaLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.recordCtaLogPrefix} $message');
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    super.key,
    this.initialPrompt,
    this.autostartWithPrompt = false,
    this.pressureCheckInStore,
    this.suggestionAttributionStore,
    this.entitlementReader,
    this.purchaseIntentStore,
    this.inviteAttributionStore,
  });

  /// Optional conversation starter from deep links / empty-state chips.
  final String? initialPrompt;

  /// When true (and mic is ready), begins recording after applying [initialPrompt].
  final bool autostartWithPrompt;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PressureCheckInStore? pressureCheckInStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final SuggestionAttributionStore? suggestionAttributionStore;

  /// Injectable for tests; defaults to the live billing-backed reader.
  final ArchiveEntitlementReader? entitlementReader;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PurchaseIntentStore? purchaseIntentStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final InviteAttributionStore? inviteAttributionStore;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  RecordUiState _ui = RecordUiState.idle;
  RecordingPhase _mic = RecordingPhase.idle;
  MicrophonePermissionState _micPermissionState =
      MicrophonePermissionState.unknown;
  bool _micPermissionUserDenied = false;
  bool _micSessionRequiresOpenSettings = false;
  bool _showMicPermissionSimulatorHelper = false;
  bool _ignoreStaleMicRefreshAfterGrant = false;
  final GlobalKey _permissionPanelKey = GlobalKey();
  int _seconds = 0;
  String? _error;
  String? _localSaveTitle;
  String? _syncNote;
  ArchiveMovementUpdate? _archiveMovement;
  int _journalEntryCount = 0;
  bool _journalEntryCountLoaded = false;
  ArchiveReturnChangesResult? _archiveReturnChangesResult;
  ArchiveReturnSnapshot? _archiveReturnCurrentSnapshot;
  List<JournalEntry> _journalEntries = const [];
  bool _hasWatchTheme = false;
  bool _betaFeedbackCaptured = false;
  DateTime? _lastReflectionAt;

  /// Saved entry dates for the 2-day activation path; falls back to
  /// count-only cautious copy when empty or unreliable.
  List<DateTime> _entryDates = const [];
  bool _firstArchiveMilestoneCompleted = false;
  bool _autostartWithPromptAttempted = false;
  String _stageLabel = '';
  PipelineStage? _pipelineStage;
  String? _selectedPromptLine;
  AudienceWedge? _audienceWedge;
  LoopMode? _activeLoop;
  String? _defaultBoundaryPauseLabel;
  String? _postSaveFollowUp;
  bool _showPostSaveLoop = false;
  bool _savedFromConfirmedRepeatTrigger = false;
  bool _savedFromHelpfulAction = false;
  bool _earlyEvidenceTriggerCaptured = false;
  bool _earlyEvidenceHelpfulCaptured = false;
  bool _earlyReturnReminderOffer = false;
  bool _earlyReturnReminderHidden = false;
  bool _lastCaptureAnalysisSucceeded = true;
  bool _lastCaptureLowQualityTranscript = false;
  bool _lastCaptureLikelySilentInput = false;
  List<JournalEntry> _entriesAfterSave = [];
  ArchiveStateObjectV3? _archiveStateAfterSave;
  InstantReflectionResponse? _instantReflectionResponse;
  DailyDiscovery? _immediateDiscovery;
  bool _immediateDiscoveryLoading = false;
  ArchiveEvolution? _postSaveEvolution;
  bool _archiveEvolutionLoading = false;
  TomorrowReturnLoop? _tomorrowReturnLoop;
  ReturnComparison? _returnComparison;
  ReturnStreak? _returnStreak;
  TomorrowCheckIn? _dueCheckInToday;
  RoutineAnchor? _dueRoutineAnchor;
  TomorrowCheckIn? _missedCheckInForDiagnosis;
  TomorrowCheckIn? _completedCheckInToday;
  PatternMemory? _patternMemory;
  PatternProgressMoment? _patternProgress;
  PatternNextAction? _patternNextAction;
  HabitProofMoment? _habitProof;
  WeeklyPatternRecap? _weeklyRecap;
  PatternShareRecap? _shareRecap;
  WatchForItem? _pendingWatchForToday;
  WatchForItem? _completedWatchForToday;
  WatchForItem? _suggestedWatchForTomorrow;
  int _watchForAlternativeIndex = 0;
  ActivePatternThread? _activePatternThread;
  bool _isFirstSessionPostSave = false;
  FirstSessionPattern? _firstSessionPattern;
  int _firstSessionAlternativeIndex = 0;
  FirstLoopActivationState _firstLoop = FirstLoopActivationState.empty;
  bool _firstLoopJustReady = false;
  String _firstLoopReadyQuestion = '';
  bool _returnDayJustClosed = false;
  FirstThreeJourneyModel? _firstThreeJourney;
  bool _watchForAcceptPending = false;
  HookRescueDecision? _hookRescue;
  String? _hookRescueNotUsefulReason;
  ArchiveFeedbackType? _feedbackHint;
  InputQualityResult? _inputQuality;
  String _inputQualityText = '';
  bool _inputQualityResolved = false;
  bool _firstRecordCardTracked = false;
  TomorrowCheckIn? _activeCheckInForTomorrow;
  TomorrowCheckIn? _recentMissedCheckIn;
  bool _retentionNextCheckJustChosen = false;
  bool _retentionDismissed = false;
  SecondSessionComparison? _secondSessionComparison;
  PatternHypothesis? _patternHypothesis;
  bool _patternHypothesisDismissed = false;
  String? _nextEvidencePrompt;
  FirstSessionPattern? _postSavePattern;
  List<PostSaveSignalFeedback> _postSaveInsightFeedback = const [];
  SelectedSignalRecord? _postSaveSelectedSignal;
  SignalArchiveSnapshot? _signalArchiveSnapshot;
  SignalJourney? _signalJourney;
  SignalReview? _signalReview;
  bool _journeyCompletionDismissed = false;
  PendingPurchaseIntent? _purchaseIntentCue;
  String? _invitedWelcomeSource;

  /// First-touch invite attribution source, when one exists — used by the
  /// invited Day 2 return copy. Stable id only, never referrer identity.
  String? _inviteSource;
  bool _hasWeeklyReviewForContinuity = false;
  bool _hasConnectedThreadForContinuity = false;
  AhaMomentCandidate? _ahaCandidate;

  /// Active UI language for post-save cards. Defaults to English; updated from
  /// reflection detection (or the screenshot override) and the language chip.
  String _languageCode = ScreenshotMode.languageCode;

  /// The originally detected language, used by the "Use detected language"
  /// override option.
  String _detectedLanguageCode = ScreenshotMode.languageCode;

  late final RecordingService _recording;
  late final CapturePipelineService _pipeline;

  @override
  void initState() {
    super.initState();
    CleanSlatePromptStore.noteSessionStart();
    final s = AppServices.instance;
    _recording = s.recording;
    _pipeline = s.pipeline;
    _recording.durationSeconds.listen((s) {
      if (mounted) setState(() => _seconds = s);
    });
    _refreshMic();
    unawaited(_loadMicPermissionSimulatorHelper());
    unawaited(
      _loadJournalEntryCount().then((_) async {
        if (_journalEntryCount >= 2) {
          unawaited(_loadFirstThreeJourney());
          unawaited(_loadActivePatternThread());
          unawaited(_loadSignalArchive());
        }
        if (_journalEntryCount >= 3) {
          await _loadPersonalReturnPrompts();
        }
      }),
    );
    _loadRecordReturnProState();
    unawaited(
      ConfirmedRepeatBetaFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      FirstSessionOnboardingStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      TesterMissionStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaTestScriptStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      CoreValueFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      BetaProofFeedbackStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ConfirmedRepeatWhyMattersStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ConfirmedRepeatThoughtMapStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      RepeatReturnCheckStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      PatternChangedStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      WhatChangedV2Store.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      CurrentRelevanceStore.ensureLoaded().then((_) async {
        await CorrectionMemoryStore.ensureLoaded();
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      HelpedTrackingStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      EntryImportanceStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      PatternNameStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      ReturnDayFlowStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      LowFrictionReturnStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      SecondMomentReturnStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      FirstProofTruthStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _loadFirstLoop();
    unawaited(_loadDefaultBoundaryPause());
    _loadReturnTriggerAccepted();
    unawaited(_loadPurchaseIntentCue());
    unawaited(_loadInvitedWelcome());
    // Persisted memory scope drives the "Memory for this entry" control
    // and every save below; refresh the UI once loaded.
    if (AppServices.isInitialized) {
      unawaited(
        MemoryScopeStore.instance().ensureLoaded().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    // Invited funnel mirror: silent unless a first-touch invite
    // attribution exists. Once per session.
    InviteFunnelMetrics.appOpened();
    final seed = widget.initialPrompt?.trim();
    if (seed != null && seed.isNotEmpty) {
      _selectedPromptLine = seed;
      ConfirmedRepeatTriggerCapture.armIfTriggerPrompt(seed);
      ConfirmedRepeatHelpfulActionCapture.armIfHelpfulPrompt(seed);
    }
    if (ScreenshotMode.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyScreenshotRecordPreview();
      });
    } else {
      unawaited(
        _loadReturnDayState().then((_) async {
          final payload = CheckInReminderService.consumeTapPayload();
          if (payload != null &&
              (payload.startsWith('next_evidence') ||
                  payload.contains('reminder'))) {
            await ReturnReasonCaptureCoordinator.markOpenedFromReminder();
          }
          // The day-2 gentle reminder was tapped to open the app.
          if (payload == DayTwoReminder.reminderId) {
            ActivationFunnelAnalytics.track(
              ActivationFunnelAnalytics.day2ReminderOpened,
              oncePerSession: true,
            );
          }
          await _applyAcquisitionIntentPrompt();
        }),
      );
      if (TrialMode.enabled) {
        unawaited(ActivationTracker.trackTrialAppOpened());
        _loadHookRescueDecision();
      }
    }
  }

  Future<void> _loadHookRescueDecision() async {
    try {
      final summary = await const TrialSummaryEngine().build();
      final decision = const HookRescueDecisionEngine().decide(summary);
      String? topReason;
      final reasons = summary.hookDiagnosis.notUsefulReasonCounts;
      if (reasons.isNotEmpty) {
        topReason = reasons.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
      }
      if (mounted) {
        setState(() {
          _hookRescue = decision;
          _hookRescueNotUsefulReason = topReason;
        });
      }
    } catch (_) {
      // Diagnosis is optional; never block the record loop.
    }
  }

  Future<void> _usePatternMemoryNext(PatternMemory memory) async {
    final checkIn = await PatternMemoryCoordinator.useNextQuestion(memory);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternMemory = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for your next check-in.')),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _usePatternNextAction(PatternNextAction action) async {
    final checkIn = await PatternMemoryCoordinator.useNextAction(action);
    if (!mounted) return;
    if (checkIn != null) {
      setState(() => _patternNextAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
      await _promptRoutineAnchorForDate(checkIn.targetDate);
    }
  }

  Future<void> _keepHabitProofGoing(HabitProofMoment proof) async {
    final checkIn = await PatternMemoryCoordinator.useHabitProofNext(proof);
    if (!mounted) return;
    setState(() => _habitProof = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  Future<void> _copyShareRecap(PatternShareRecap recap) async {
    await PatternShareService.copyToClipboard(recap);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recap copied.')));
  }

  Future<void> _useWeeklyRecapNext(WeeklyPatternRecap recap) async {
    final checkIn = await PatternMemoryCoordinator.useWeeklyRecapNext(recap);
    if (!mounted) return;
    setState(() => _weeklyRecap = null);
    if (checkIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved for tomorrow\u2019s check.')),
      );
    }
  }

  @override
  void dispose() {
    if (TrialMode.enabled) {
      if (_ui == RecordUiState.recording) {
        unawaited(ActivationTracker.trackTrialRecordingCancelled());
      }
      if (_watchForAcceptPending) {
        unawaited(
          ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
        );
      }
    }
    // Leaving with an answer chosen but no recorded moment is a return-day drop.
    unawaited(
      ReturnDayFrictionCoordinator.trackAbandonedAfterAnswerIfPending(),
    );
    super.dispose();
  }

  Future<void> _loadActivePatternThread() async {
    final thread = await ActivePatternThreadCoordinator.loadCurrentThread();
    if (!mounted) return;
    setState(() => _activePatternThread = thread);
  }

  Future<void> _loadSignalArchive() async {
    final snapshot = await SignalArchiveCoordinator.load();
    final journey = await SignalJourneyCoordinator.loadActive();
    SignalReview? review;
    if (journey != null && journey.supportingCount >= 3) {
      review = await SignalReviewCoordinator.loadForActiveJourney();
    }
    if (!mounted) return;
    setState(() {
      _signalArchiveSnapshot = snapshot;
      _signalJourney = journey;
      _signalReview = review;
    });
  }

  void _applyScreenshotRecordPreview() {
    if (ArchiveMeDemoState.isActive) {
      final entries = ArchiveMeDemoArchive.journalEntries();
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = entries.length;
        _journalEntryCountLoaded = true;
        _journalEntries = entries;
        _earlyEvidenceTriggerCaptured = true;
        _earlyEvidenceHelpfulCaptured = true;
        _showPostSaveLoop = false;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.objectiveDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveFirstMomentPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.objectiveNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.compellingCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 1;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.realReminderPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionCheckSetPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionDueTodayPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionLoopClosedPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _dueCheckInToday = null;
        _activeCheckInForTomorrow = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.retentionNextReadyPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _retentionNextCheckJustChosen = true;
        _activeCheckInForTomorrow =
            ScreenshotSampleData.tomorrowCheckInSetForTomorrowSample;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanFirstRunPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordCleanDueCheckPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 3;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    if (ScreenshotMode.recordCleanPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _patternMemory = ScreenshotSampleData.patternMemorySample;
        _patternProgress = ScreenshotSampleData.patternProgressSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _inputQualityResolved = true;
      });
      return;
    }
    if (ScreenshotMode.positioningRescuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueFirstRecordPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _dueCheckInToday = null;
        _showPostSaveLoop = false;
        _firstThreeJourney = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueTomorrowCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueUsefulResultPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.activationRescueNextCheckPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.quickHelpPreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = 0;
        _showPostSaveLoop = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showQuickHelpSheet(
          context,
          languageCode: _languageCode,
          onStartRecording: () => _onRecordPressed(source: 'main'),
          initialIntent: QuickHelpIntent.whatToRecord,
        );
      });
      return;
    }
    final journeyCount = ScreenshotMode.screenshotJourneyReflectionCount;
    if (journeyCount >= 0) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _journalEntryCount = journeyCount;
        _firstThreeJourney = ScreenshotSampleData.firstThreeJourneyForCount(
          journeyCount,
        );
        _showPostSaveLoop = false;
        _pendingWatchForToday = journeyCount >= 2
            ? ScreenshotSampleData.watchForPendingForToday(DateTime.now())
            : null;
        _activePatternThread = journeyCount >= 1
            ? ScreenshotSampleData.activePatternThreadSample
            : null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
      });
      return;
    }
    if (ScreenshotMode.recordFirstSessionPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = null;
        _returnStreak = null;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.completedCheckInPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _returnDayJustClosed = false;
        _completedCheckInToday =
            ScreenshotSampleData.tomorrowCheckInCompletedSample;
        if (ScreenshotMode.kindnessPreview) {
          _inputQualityText = ScreenshotSampleData.selfBlameReflection;
        }
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.inputQualityCoachPreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _isFirstSessionPostSave = true;
        _firstSessionPattern = ScreenshotSampleData.firstSessionPatternSample;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _inputQuality = assessReflectionQuality('Today was stressful.');
        _inputQualityText = 'Today was stressful.';
        _inputQualityResolved = false;
        _completedWatchForToday = null;
        _suggestedWatchForTomorrow = null;
        _pendingWatchForToday = null;
        _activePatternThread = null;
      });
      return;
    }
    if (ScreenshotMode.recordPostSavePreview) {
      setState(() {
        _ui = RecordUiState.done;
        _showPostSaveLoop = true;
        _tomorrowReturnLoop = ScreenshotSampleData.tomorrowReturnLoop;
        _returnComparison = ScreenshotSampleData.returnComparisonSample;
        _returnStreak = ScreenshotSampleData.returnStreakSample;
        _completedWatchForToday = ScreenshotSampleData.watchForCompletedSample;
        _suggestedWatchForTomorrow =
            ScreenshotSampleData.watchForPendingForToday(
              DateTime.now().add(const Duration(days: 1)),
            );
        _pendingWatchForToday = null;
        _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      });
      return;
    }
    if (ScreenshotMode.recordCheckInDuePreview) {
      setState(() {
        _ui = RecordUiState.ready;
        _mic = RecordingPhase.ready;
        _dueCheckInToday = ScreenshotSampleData.tomorrowCheckInDueSample;
        _pendingWatchForToday = null;
        _activePatternThread = null;
        _showPostSaveLoop = false;
      });
      return;
    }
    setState(() {
      _ui = RecordUiState.ready;
      _mic = RecordingPhase.ready;
      _pendingWatchForToday = ScreenshotSampleData.watchForPendingForToday(
        DateTime.now(),
      );
      _activePatternThread = ScreenshotSampleData.activePatternThreadSample;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _showPostSaveLoop = false;
    });
  }

  Future<void> _loadReturnDayState() async {
    final due = await TomorrowCheckInCoordinator.loadDueToday();
    final missed = due == null
        ? await TomorrowCheckInCoordinator.loadMissedNeedingReason()
        : null;
    final recentMissed = due == null && missed == null
        ? await TomorrowCheckInCoordinator.loadRecentMissed()
        : null;
    final active = await TomorrowCheckInCoordinator.loadActive();
    final tomorrowKey = _tomorrowDateKey;
    TomorrowCheckIn? activeForTomorrow;
    if (active != null &&
        !active.isCompleted &&
        active.targetDate == tomorrowKey) {
      activeForTomorrow = active;
    }
    WatchForItem? pending;
    if (due == null) {
      pending = await WatchForCoordinator.loadPendingForToday();
    }
    if (due != null || pending != null) {
      await ActivationTracker.trackReturnedNextDayOnce();
    }
    RoutineAnchor? dueAnchor;
    if (due != null) {
      // Seeing yesterday's question is the first return-day step.
      await ReturnDayFrictionCoordinator.markDueShown(due.id);
      dueAnchor = await RoutineAnchorStore.instance().loadForDate(
        due.targetDate,
      );
    }
    ArchiveFeedbackType? feedbackHint;
    try {
      feedbackHint = await ArchiveFeedbackCoordinator.latestDominantIssue();
    } catch (_) {
      // Feedback is optional; never block the record loop.
    }
    if (!mounted) return;
    setState(() {
      _dueCheckInToday = due;
      _dueRoutineAnchor = dueAnchor;
      _missedCheckInForDiagnosis = missed;
      _recentMissedCheckIn = recentMissed;
      _activeCheckInForTomorrow = activeForTomorrow;
      _pendingWatchForToday = pending;
      _feedbackHint = feedbackHint;
    });
  }

  /// ISO date key for tomorrow, matching how check-ins set their targetDate.
  String get _tomorrowDateKey =>
      tomorrowCheckInDateKey(DateTime.now().add(const Duration(days: 1)));

  /// Shows the routine-anchor chooser and stores the chosen moment for the
  /// given target date so the due card can show "Planned for: …".
  Future<void> _promptRoutineAnchorForDate(String targetDate) async {
    if (!mounted) return;
    final anchor = await RoutineAnchorChooser.show(context);
    if (anchor == null) return;
    await RoutineAnchorStore.instance().saveForDate(targetDate, anchor);
  }

  bool get _isFlutterWidgetTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _loadJournalEntryCount() async {
    if (_isFlutterWidgetTest) {
      // Widget tests do not run initState file I/O unless wrapped in runAsync.
      // Use the journal cache so empty-gate UI can render deterministically.
      _applyLoadedJournalEntryCount(
        AppServices.instance.journalStore.loadAllSync(),
        hasWatchTheme: false,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
      );
      return;
    }

    final all = await AppServices.instance.journal.loadAll();
    await BetaFeedbackStore.ensureLoaded();
    final watchItems = await ArchiveWatchlistStore(AppServices.instance.prefs)
        .loadItems();
    if (!mounted) return;
    _applyLoadedJournalEntryCount(
      all,
      hasWatchTheme: watchItems.isNotEmpty,
      betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
    );
    unawaited(_loadEarlyEvidenceMilestones());
  }

  Future<void> _loadEarlyEvidenceMilestones() async {
    final trigger =
        await EarlyEvidenceMilestoneStore.instance().readTriggerCaptured();
    final helpful =
        await EarlyEvidenceMilestoneStore.instance().readHelpfulActionCaptured();
    final earlyReturnReminderOffer =
        await EarlyArchiveReturnReminderStore.instance().shouldOffer();
    if (!mounted) return;
    setState(() {
      _earlyEvidenceTriggerCaptured = trigger;
      _earlyEvidenceHelpfulCaptured = helpful;
      _earlyReturnReminderOffer = earlyReturnReminderOffer;
    });
  }

  void _applyLoadedJournalEntryCount(
    List<JournalEntry> all, {
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
  }) {
    if (!mounted) return;
    setState(() {
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _hasWatchTheme = hasWatchTheme;
      _betaFeedbackCaptured = betaFeedbackCaptured;
      _lastReflectionAt = all.isEmpty ? null : all.last.createdAt;
      _entryDates = all.map((e) => e.createdAt).toList();
      _firstArchiveMilestoneCompleted =
          ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(all);
      if (ArchiveMeDemoState.isActive) {
        _earlyEvidenceTriggerCaptured = true;
        _earlyEvidenceHelpfulCaptured = true;
      }
    });
    unawaited(_refreshArchiveReturnChanges(all));
    _logRecordEmptyGate('journal_loaded');
    unawaited(BetaActivationLoopTracker.trackRecordScreenSeen());
  }

  Future<void> _refreshArchiveReturnChanges(List<JournalEntry> entries) async {
    final store = ArchiveReturnChangesStore.fromAppPrefs(
      AppServices.instance.prefs,
    );
    final resolved = await resolveArchiveReturnChanges(
      entries: entries,
      store: store,
    );
    if (!mounted) return;
    setState(() {
      _archiveReturnCurrentSnapshot = resolved.current;
      _archiveReturnChangesResult = resolved.result;
    });
  }

  Future<void> _markArchiveReturnChangesSeen() async {
    final snapshot = _archiveReturnCurrentSnapshot;
    if (snapshot == null) return;
    await ArchiveReturnChangesStore.fromAppPrefs(
      AppServices.instance.prefs,
    ).markSeen(snapshot);
    if (!mounted) return;
    setState(() => _archiveReturnChangesResult = null);
  }

  bool _returnTriggerAccepted = false;
  PersonalReturnPromptSet? _personalReturnPrompts;
  DailyReturnSuggestionSet _dailyReturnSuggestions =
      DailyReturnSuggestionSet.empty;
  OneSmallRecording _oneSmallRecording = OneSmallRecording.none();

  /// Suggestion-to-Pro funnel state. The pending source is set on tap and
  /// consumed on the next successful save — never blocks recording.
  PaywallSource? _pendingSuggestionSource;
  DailyReturnSuggestion? _pendingTappedSuggestion;
  bool _dailySuggestionsSeenTracked = false;
  PaywallSource? _suggestionProNudgeSource;

  /// Post-save "Saved to your archive" receipt for suggestion-sourced saves.
  StartHereSaveReceipt? _saveReceipt;

  /// Post-save "Done for today" closure receipt — every successful save.
  DoneForTodayReceipt? _doneForTodayReceipt;
  DayTwoReturnPreview? _dayTwoReturnPreview;

  /// One optional day-2 reminder offer — only after the very first save.
  bool _offerDayTwoReminder = false;

  /// Post-save archive proof counter — real evidence counts, never fabricated.
  ArchiveProofCounter? _archiveProofCounter;

  /// Post-save optional context tag prompt — only after a successful save.
  bool _showEvidenceContextTag = false;

  /// Post-save anonymous share card — counts only, never user text.
  ShareableArchiveProof? _shareableProof;

  /// Post-save Pro bridge — only after a real value moment, never blocking.
  ValueMomentBridge? _valueMomentBridge;

  /// Record → Return → Pro loop: true only while the very first save's
  /// post-save view is showing.
  bool _recordReturnProJustSaved = false;

  /// Loop persisted progress (return cue, Pro bridge, change-start seen).
  RecordReturnProState? _recordReturnProState;

  /// Pro users never see the commercial-loop Pro bridge.
  bool _recordReturnProIsPro = false;

  /// The post-save Pro nudge shows at most once per app session.
  static bool _suggestionProNudgeShownThisSession = false;

  @visibleForTesting
  static void resetSuggestionProNudgeSessionForTest() {
    _suggestionProNudgeShownThisSession = false;
  }

  SuggestionAttributionStore? get _suggestionAttribution =>
      widget.suggestionAttributionStore ??
      (AppServices.isInitialized
          ? SuggestionAttributionStore.instance()
          : null);

  void _onDailySuggestionTapped(
    DailyReturnSuggestion suggestion,
    bool isPrimary,
  ) {
    final source = isPrimary
        ? PaywallSource.startHereToday
        : PaywallSource.dailySuggestion;
    _pendingSuggestionSource = source;
    _pendingTappedSuggestion = suggestion;
    final store = _suggestionAttribution;
    if (store == null) return;
    unawaited(
      store.record(
        SuggestionAttributionEventType.tappedFor(source),
        suggestionId: suggestion.id,
      ),
    );
  }

  /// Records the saved-from-suggestion event and shows the "Saved to your
  /// archive" receipt for suggestion-sourced saves. Runs only after the save
  /// fully succeeded — generic prompt saves never reach the receipt.
  Future<void> _handleSuggestionAttributionAfterSave(int entryCount) async {
    final source = _pendingSuggestionSource;
    final tapped = _pendingTappedSuggestion;
    if (source == null) return;
    _pendingSuggestionSource = null;
    _pendingTappedSuggestion = null;

    final store = _suggestionAttribution;
    if (store != null) {
      unawaited(store.record(SuggestionAttributionEventType.savedFor(source)));
    }

    final receipt = const StartHereSaveReceiptEngine().build(
      source: source,
      suggestion: tapped,
    );
    if (receipt != null) {
      if (!mounted) return;
      setState(() => _saveReceipt = receipt);
      return;
    }

    // Fallback when no tapped suggestion was retained: the gentle Pro nudge.
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!SuggestionProTrigger.shouldShow(
      isPro: isPro,
      entryCount: entryCount,
      alreadyShownThisSession: _suggestionProNudgeShownThisSession,
    )) {
      return;
    }
    _suggestionProNudgeShownThisSession = true;
    if (!mounted) return;
    setState(() => _suggestionProNudgeSource = source);
  }

  Future<void> _loadReturnTriggerAccepted() async {
    if (!AppServices.isInitialized) return;
    final accepted = await PressureReturnTriggerStore.instance().accepted;
    if (!mounted) return;
    setState(() => _returnTriggerAccepted = accepted);
  }

  /// Builds "Try saying one of these" and "Worth checking today" from the
  /// user's own pressure entries when there is evidence; otherwise the
  /// section keeps generic prompts and no suggestion card is shown.
  Future<void> _loadPersonalReturnPrompts() async {
    if (!_journalEntryCountReady || _journalEntryCount < 3) return;
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final records = await store.loadAll();
    final savedEntryCount = _journalEntryCount;
    if (!mounted) return;
    setState(() {
      _personalReturnPrompts = const PersonalReturnPromptEngine().build(
        records,
      );
      _dailyReturnSuggestions = const DailyReturnSuggestionEngine().build(
        records,
      );
      _oneSmallRecording = const OneSmallRecordingEngine().build(
        records,
        entryCount: savedEntryCount,
      );
      // Day 7 continuity inputs — both from existing engines, never new
      // claims. The loop itself is built at render time with the current
      // entry count.
      _hasWeeklyReviewForContinuity = const WeeklyThreadReviewEngine()
          .build(records)
          .hasReview;
      _hasConnectedThreadForContinuity = const ThreadReturnEvidenceEngine()
          .build(records)
          .hasEvidence;
    });
    await AhaMomentStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _ahaCandidate = const AhaMomentEngine().evaluate(
        records: records,
        entryCount: savedEntryCount,
        hasStrongerMemoryCardVisible: false,
        source: 'record',
        trackAnalytics: false,
      );
    });
    if (_dailyReturnSuggestions.hasSuggestions &&
        !_dailySuggestionsSeenTracked) {
      _dailySuggestionsSeenTracked = true;
      final store = _suggestionAttribution;
      if (store != null) {
        unawaited(
          store.record(SuggestionAttributionEventType.dailySuggestionsSeen),
        );
      }
    }
  }

  /// Return cue is on screen — first save only, until answered once.
  bool get _recordReturnCueVisible =>
      _recordReturnProJustSaved &&
      _recordReturnProState != null &&
      !_recordReturnProState!.returnCueResolved;

  Future<void> _loadRecordReturnProState() async {
    if (!AppServices.isInitialized) return;
    await ProEvidenceValueDismissStore.ensureLoaded();
    await ProLockMomentDismissStore.ensureLoaded();
    await MonthlyPrivateReportDismissStore.ensureLoaded();
    await BetaFeedbackIntelligenceStore.ensureLoaded();
    final state = await RecordReturnProStore.instance().load();
    final isPro =
        await (widget.entitlementReader ??
                ArchiveEntitlementReader.forAccessCheck())
            .isPro;
    if (!mounted) return;
    setState(() {
      _recordReturnProState = state;
      _recordReturnProIsPro = isPro;
    });
  }

  bool get _hasRealChangeInsight => RecordReturnProGates.hasRealChangeInsight(
    hasReturnComparison: _returnComparison != null,
    hasTomorrowReturnLoopContent: _tomorrowReturnLoop?.hasContent ?? false,
    hasThreadReturnEvidence: _hasConnectedThreadForContinuity,
  );

  /// "Remind me tomorrow" — permission only after this explicit tap.
  Future<void> _acceptRecordReturnReminder() async {
    final outcome = await DayTwoReminderCoordinator().accept();
    await RecordReturnProStore.instance().markReturnCueResolved(
      RecordReturnProReturnCueMethod.reminder,
    );
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        returnCueResolved: true,
        returnCueMethod: RecordReturnProReturnCueMethod.reminder,
      );
      _offerDayTwoReminder = false;
    });
    final line = outcome == DayTwoReminderOutcome.scheduled
        ? DayTwoReminder.scheduledLine
        : DayTwoReminder.unavailableLine;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(line)));
  }

  /// Local return cue only — no notifications.
  Future<void> _acceptRecordReturnLocalCue() async {
    await RecordReturnProStore.instance().markReturnCueResolved(
      RecordReturnProReturnCueMethod.localCue,
    );
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        returnCueResolved: true,
        returnCueMethod: RecordReturnProReturnCueMethod.localCue,
      );
    });
  }

  Future<void> _markChangeStartSeen() async {
    await RecordReturnProStore.instance().markChangeStartSeen();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        changeStartSeen: true,
      );
    });
  }

  void _handleThoughtMapMissingPiece(ThoughtMapResult map) {
    final missing = map.sections.where((section) => !section.isKnown);
    if (missing.isEmpty) return;
    final section = missing.first;
    ConfirmedRepeatThoughtMapAnalytics.recordMissingPieceTapped(
      section: section.id,
      surface: 'record',
      entryCount: _journalEntryCount,
    );
    unawaited(
      ConfirmedRepeatThoughtMapStore.instance().markMissingPieceTarget(
        section.id,
      ),
    );
    if (section.id == ThoughtMapSectionId.trigger) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (section.id == ThoughtMapSectionId.result) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = section.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'thought_map'));
  }

  void _handlePositiveReinforcementRecordAgain(
    PositiveReinforcementResult reinforcement,
  ) {
    PositiveReinforcementAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      helpfulPatternRecorded: true,
    );
    ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    setState(
      () => _selectedPromptLine = reinforcement.guidedRecordPrompt,
    );
    unawaited(_onRecordPressed(source: 'positive_reinforcement'));
  }

  void _handlePatternChangedRecord(PatternChangedResult result) {
    PatternChangedAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      changeType: result.type,
    );
    unawaited(_onRecordPressed(source: 'pattern_changed'));
  }

  void _handleArchiveSummaryRecordNext(ArchiveSummaryResult summary) {
    final recordNext = summary.recordNext;
    if (recordNext.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (recordNext.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = recordNext.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'archive_summary'));
  }

  void _handleDailyReturnReason(DailyReturnReasonResult reason) {
    DailyReturnReasonAnalytics.recordTapped(
      kind: reason.kind,
      surface: 'record',
      entryCount: _journalEntryCount,
    );
    if (reason.needsTriggerCapture) {
      ConfirmedRepeatTriggerCapture.armForNextSave();
    } else if (reason.needsResultCapture) {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
    }
    setState(() => _selectedPromptLine = reason.guidedRecordPrompt);
    unawaited(_onRecordPressed(source: 'daily_return_reason'));
  }

  Future<void> _handleFirstProofWatchThisNext() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) {
      _resetPostSaveToReady();
      return;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final phrase = ReturnTomorrowCueEngine.groundedWatchingPhrase(eligible);
    final watch = WatchForCoordinator.buildSuggestedWatchForAfterSave(
      entries: entries,
      loop: _tomorrowReturnLoop,
      signals: phrase != null ? [phrase] : _postSaveSignals(),
    );
    await WatchForCoordinator.acceptSuggestedWatchFor(watch);
    if (!mounted) return;
    if (phrase != null && phrase.trim().isNotEmpty) {
      setState(() => _selectedPromptLine = 'Watch for: $phrase');
    }
    _resetPostSaveToReady();
  }

  void _openPatternDetailFromRecord() {
    final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: _journalEntries);
    final earlyEvidenceTimeline = EarlyEvidenceTimelineEngine.build(
      entries: _journalEntries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeat = earlyEvidenceTimeline != null ||
        (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final repeatReturnChangeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: _journalEntryCount,
      viewingConfirmedRepeat: viewingConfirmedRepeat,
      isRecording: false,
      isPostSave: false,
      records: RepeatReturnCheckStore.cached,
    );
    final detail = PatternDetailEngine.build(
      entries: _journalEntries,
      confirmedRepeat: earlyFirstSignal,
      changeProof: repeatReturnChangeProof,
      returnChecks: RepeatReturnCheckStore.cached,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    if (detail == null) return;

    final shareCard = ShareCardBuilder.build(
      entries: _journalEntries,
      detail: detail,
      confirmedRepeat: earlyFirstSignal,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    unawaited(
      PatternDetailSheet.show(
        context,
        detail: detail,
        buildInput: PatternDetailBuildInput(
          entries: _journalEntries,
          confirmedRepeat: earlyFirstSignal,
          changeProof: repeatReturnChangeProof,
          returnChecks: RepeatReturnCheckStore.cached,
          triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
        ),
        entryCount: _journalEntryCount,
        isPro: _recordReturnProIsPro,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source: PaywallSource.valueMoment,
                    sourceRoute: '/record',
                  ),
                ),
        shareCard: shareCard,
      ),
    );
  }

  void _openFirstProofPatternDetail() {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final earlyFirstSignal = EarlyFirstSignalEngine.build(entries: entries);
    final earlyEvidenceTimeline = EarlyEvidenceTimelineEngine.build(
      entries: entries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    final viewingConfirmedRepeat = earlyEvidenceTimeline != null ||
        (earlyFirstSignal?.showsConfirmedRepeat ?? false);
    final repeatReturnChangeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeat,
      isRecording: false,
      isPostSave: true,
      records: RepeatReturnCheckStore.cached,
    );
    final detail = PatternDetailEngine.build(
      entries: entries,
      confirmedRepeat: earlyFirstSignal,
      changeProof: repeatReturnChangeProof,
      returnChecks: RepeatReturnCheckStore.cached,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    if (detail == null) return;

    final shareCard = ShareCardBuilder.build(
      entries: entries,
      detail: detail,
      confirmedRepeat: earlyFirstSignal,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
    );
    unawaited(
      PatternDetailSheet.show(
        context,
        detail: detail,
        buildInput: PatternDetailBuildInput(
          entries: entries,
          confirmedRepeat: earlyFirstSignal,
          changeProof: repeatReturnChangeProof,
          returnChecks: RepeatReturnCheckStore.cached,
          triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
          helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeat,
        ),
        entryCount: entries.length,
        isPro: _recordReturnProIsPro,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source: PaywallSource.valueMoment,
                    sourceRoute: '/record',
                  ),
                ),
        shareCard: shareCard,
      ),
    );
  }

  Future<void> _openFirstProofRenamePattern() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final prompt = PatternNameEngine.buildPrompt(entries: entries);
    final payoff = FirstProofPayoffEngine.build(entries: entries);
    final groundedPhrase =
        prompt?.groundedPhrase ?? payoff?.groundedPhrase ?? '';
    if (groundedPhrase.trim().isEmpty) return;

    final patternKey = PatternNameEngine.patternKey(groundedPhrase);
    final initialName =
        PatternNameEngine.displayLabelForGroundedPhrase(groundedPhrase);
    final saved = await RenamePatternSheet.show(
      context,
      initialName: initialName,
      onSave: (name) {
        PatternNameStore.setCustomName(patternKey, name);
        PatternNameAnalytics.renamed(
          source: 'first_proof_action_loop',
          entryCount: entries.length,
          hasCustomName: true,
        );
      },
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _excludeLatestFromFirstProofPattern() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(entries);
    final entryId = entries.last.id;
    if (patternKey == null || entryId.isEmpty) return;

    await ArchivePatternExclusionActions.excludeFromPattern(
      context: context,
      entryId: entryId,
      patternKey: patternKey,
      source: 'first_proof_action_loop',
    );
  }

  Future<void> _openFirstProofPatternCorrection() async {
    final entries = _entriesAfterSave;
    if (entries.isEmpty) return;

    final payoff = FirstProofPayoffEngine.build(entries: entries);
    if (payoff == null) return;
    if (!PatternCorrectionGates.shouldShowForFirstProofNo(
      entries: entries,
      payoff: payoff,
    )) {
      return;
    }

    await PatternCorrectionSheet.show(
      context,
      contextData: PatternCorrectionGates.buildForFirstProofNo(
        entries: entries,
        payoff: payoff,
        onKeepRecording: _keepRecording,
      ),
    );
  }

  void _openWeeklyArchiveReview(WeeklyArchiveReviewResult review) {
    WeeklyArchiveWeekReviewAnalytics.recordTapped(
      surface: 'record',
      entryCount: _journalEntryCount,
      hasRepeat: review.whatRepeated?.isSupported ?? false,
      hasChange: review.whatChanged?.isSupported ?? false,
      hasPositivePattern: review.whatHelped?.isSupported ?? false,
    );
    unawaited(
      WeeklyArchiveReviewSheet.show(
        context,
        review: review,
        isPro: _recordReturnProIsPro,
        entryCount: _journalEntryCount,
        entries: _journalEntries,
        onSeePro: _recordReturnProIsPro
            ? null
            : () => context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source: PaywallSource.valueMoment,
                    sourceRoute: '/record',
                  ),
                ),
      ),
    );
  }

  /// Resolves the commercial-loop Pro bridge once.
  Future<void> _resolveRecordReturnProBridge({required bool seePro}) async {
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        proBridgeResolved: true,
      );
    });
    if (seePro) {
      context.push(
        '/subscription',
        extra: PaywallRouteArgs(
          source: PaywallSource.valueMoment,
          sourceRoute: '/record',
        ),
      );
    }
  }

  Future<void> _dismissProLockMoment() async {
    await ProLockMomentDismissStore.dismiss();
    if (mounted) setState(() {});
  }

  Future<void> _dismissMonthlyPrivateReportPreview() async {
    await MonthlyPrivateReportDismissStore.dismiss();
    if (mounted) setState(() {});
  }

  Future<void> _dismissProEvidenceValueBridge() async {
    await ProEvidenceValueEngine.dismissForSession();
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (mounted) setState(() {});
  }

  void _openProEvidenceValueSubscription({required String analyticsSource}) {
    EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
      source: analyticsSource,
    );
    context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        source: PaywallSource.valueMoment,
        sourceRoute: '/record',
      ),
    );
  }

  /// Builds the "Done for today" closure receipt — only ever called after a
  /// save succeeded, so a failed save can never surface it.
  Future<void> _buildDoneForTodayReceipt() async {
    List<PressureCheckInRecord> records = const [];
    if (widget.pressureCheckInStore != null || AppServices.isInitialized) {
      final store =
          widget.pressureCheckInStore ?? PressureCheckInStore.instance();
      records = await store.loadAll();
    }
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    // Day 2 gentle reminder: offered once, only right after the very first
    // successful save — value exists before anything is asked.
    final offerDayTwoReminder = await DayTwoReminderCoordinator().shouldOffer(
      entryCount: _journalEntryCount,
    );
    // First 60 Seconds: load the persisted return-cue / Pro-bridge answers
    // so neither card ever re-asks after being resolved.
    final recordReturnProState = await RecordReturnProStore.instance().load();
    if (!mounted) return;
    setState(() {
      _offerDayTwoReminder = offerDayTwoReminder;
      _recordReturnProState = recordReturnProState;
      _recordReturnProIsPro = isPro;
      _doneForTodayReceipt = const DoneForTodayReceiptEngine().build(
        saved: true,
        entryCount: _journalEntryCount,
        records: records,
      );
      // Same evidence, one more honest count: the save that just happened.
      _archiveProofCounter = const ArchiveProofCounterEngine().build(
        records,
        savedToday: true,
      );
      // Anonymous share card built from the same counts — never user text.
      _shareableProof = const ShareableArchiveProofEngine().build(
        records,
        savedToday: true,
        entryCount: _journalEntryCount,
      );
      // Pro bridge only after a real value moment — and the save is already
      // done, so it can never block recording or saving.
      _valueMomentBridge = const ValueMomentPaywallTrigger().build(
        records,
        isPro: isPro,
      );
      // Optional, skippable context tag — only reachable after a real save.
      _showEvidenceContextTag = _entriesAfterSave.isNotEmpty;
      // Tomorrow's-check preview — safe labels only, never user text.
      _dayTwoReturnPreview = const DayTwoReturnPreviewEngine().build(
        entryCount: _journalEntryCount,
        contextTagIds: [for (final r in records) ...r.contextIds],
        entryDates: [for (final r in records) r.createdAt],
      );
    });
  }

  /// Persists a one-tap low-effort check-in as a real lightweight evidence
  /// record. The card only confirms "Saved" after this completes.
  Future<void> _saveLowEffortCheckIn(LowEffortCheckInOption option) async {
    if (widget.pressureCheckInStore == null && !AppServices.isInitialized) {
      return;
    }
    final store =
        widget.pressureCheckInStore ?? PressureCheckInStore.instance();
    final existing = await store.loadAll();
    await store.save(
      const LowEffortCheckInEngine().buildRecord(option, existing),
    );
  }

  /// Stores the single optional context tag on the journal entry that was
  /// just saved, then retires the prompt. Skipping never stores anything.
  Future<void> _saveEvidenceContextTag(String tagId) async {
    setState(() => _showEvidenceContextTag = false);
    final entry = _lastSavedEntry;
    if (entry == null) return;
    if (!AppServices.isInitialized) return;
    final tagged = CaptureContextTags.applyTag(entry, tagId);
    await AppServices.instance.journalStore.save(
      tagged,
      first25Source: 'capture_context_tag',
    );
    if (!mounted) return;
    setState(() {
      if (_entriesAfterSave.isNotEmpty &&
          _entriesAfterSave.first.id == tagged.id) {
        _entriesAfterSave = [
          tagged,
          ..._entriesAfterSave.skip(1),
        ];
      }
    });
  }

  Future<void> _loadFirstThreeJourney() async {
    if (!_journalEntryCountReady || _journalEntryCount < 2) return;
    final model = await FirstThreeJourneyCoordinator.load();
    if (!mounted) return;
    setState(() => _firstThreeJourney = model);
  }

  /// Purchase Intent Return Cue: a previous purchase start without a
  /// completion, surfaced calmly on a later visit. Loaded once at init —
  /// the session that started the purchase never shows it.
  Future<void> _loadPurchaseIntentCue() async {
    if (widget.purchaseIntentStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.purchaseIntentStore ?? PurchaseIntentStore();
    final intent = await store.pendingIntent();
    if (intent == null) return;
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!mounted) return;
    if (!PurchaseIntentReturnCue.shouldShow(
      isPro: isPro,
      hasPendingIntent: true,
    )) {
      return;
    }
    PurchaseIntentReturnCue.shownThisSession = true;
    setState(() => _purchaseIntentCue = intent);
  }

  /// Invited User Welcome: a locally persisted first-touch invite
  /// attribution tailors the pre-first-save welcome. Loaded once at init;
  /// the render gate also requires a still-empty archive.
  Future<void> _loadInvitedWelcome() async {
    if (widget.inviteAttributionStore == null && !AppServices.isInitialized) {
      return;
    }
    final store = widget.inviteAttributionStore ?? InviteAttributionStore();
    final attribution = await store.firstTouch();
    if (attribution == null || !mounted) return;
    // Any invited surface (welcome, Day 2 return copy) can use the source.
    setState(() => _inviteSource = attribution.source);
    if (!InvitedUserWelcome.shouldShow(entryCount: _journalEntryCount)) return;
    InvitedUserWelcome.shownThisSession = true;
    InvitedUserWelcome.sessionSource = attribution.source;
    setState(() => _invitedWelcomeSource = attribution.source);
  }

  Future<void> _loadFirstLoop() async {
    // Opening the Record tab is the first step of the compressed loop.
    final state = ScreenshotMode.enabled
        ? await FirstLoopActivationCoordinator.load()
        : await FirstLoopActivationCoordinator.markOpenedRecord();
    if (!mounted) return;
    setState(() => _firstLoop = state);
  }

  Future<void> _loadDefaultBoundaryPause() async {
    if (ScreenshotMode.enabled || !AppServices.isInitialized) return;
    await CapacityBoundaryResponseStore.ensureLoaded();
    final loop = _activeLoop ?? await LoopModeCoordinator.loadActive();
    final selection = CapacityBoundaryResponseStore.cached;
    final text = selection != null && selection.hasSelection
        ? CapacityBoundaryResponseCopy.textForId(selection.responseId)
        : null;
    if (!mounted) return;
    setState(() {
      _defaultBoundaryPauseLabel = text != null && (loop?.isCapacityYes ?? false)
          ? CapacityBoundaryResponseCopy.recordDefaultPauseLabel(text)
          : null;
    });
  }

  bool _showBeforeYesCardOnRecord(RecordUiState ui) =>
      !_shouldHideCompetingRecordCtas(ui) &&
      _activeLoop?.isCapacityYes == true &&
      CapacityLoopGates.showRecordPrompt(
        capacityWedgeActive: true,
        sampleMode: ScreenshotMode.enabled,
      ) &&
      ui == RecordUiState.ready &&
      _mic == RecordingPhase.ready &&
      _postSavePattern == null;

  bool _showDefaultBoundaryPauseOnRecord(RecordUiState ui) =>
      _defaultBoundaryPauseLabel != null &&
      _activeLoop?.isCapacityYes == true &&
      ui == RecordUiState.ready &&
      _postSavePattern == null &&
      !_shouldHideCompetingRecordCtas(ui) &&
      !_showBeforeYesCardOnRecord(ui);

  bool get _showAdvancedRetentionPostSave {
    if (_isFirstSessionPostSave) return false;
    final count = _entriesAfterSave.isNotEmpty
        ? _entriesAfterSave.length
        : _journalEntryCount;
    return count >= 3;
  }

  void _onStartHereSelected(String prompt) {
    setState(() => _selectedPromptLine = prompt);
    if (_ui == RecordUiState.ready && _mic == RecordingPhase.ready) {
      unawaited(_onRecordPressed(source: 'moment'));
    }
  }

  ArchivePromptSet _promptSet() {
    final hasBelief = _journalEntryCount >= 5;
    final movement = _archiveMovement;
    return buildArchivePrompts(
      hasBelief: hasBelief,
      strengthening:
          movement?.kind == ArchiveMovementKind.confidenceChanged &&
          (movement?.headline.toLowerCase().contains('stronger') ?? false),
      weakening: movement?.headline.toLowerCase().contains('weaken') ?? false,
      hasRecentChange: movement != null,
      hasOpenQuestion: hasBelief && _journalEntryCount < 8,
      missingAreaLabel: movement?.kind == ArchiveMovementKind.newLifeArea
          ? 'that area'
          : null,
      beliefSnippet: movement?.headline,
    );
  }

  RecordUiState _uiForMicPhase(RecordingPhase cap) {
    return RecordMicrophonePermissionUi.uiForMicPhase(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
    );
  }

  Future<void> _loadMicPermissionSimulatorHelper() async {
    final showHelper = await MicrophonePermissionEnvironment.isIosSimulator();
    if (!mounted) return;
    if (_showMicPermissionSimulatorHelper != showHelper) {
      setState(() => _showMicPermissionSimulatorHelper = showHelper);
    }
  }

  Future<void> _openMicSettings() async {
    _ignoreStaleMicRefreshAfterGrant = false;
    await openMicrophoneSettings();
    await _refreshMic();
  }

  Future<void> _typeInsteadFromPermission() async {
    await navigateToTypeInsteadCapture(
      context,
      prompt: _selectedPromptLine,
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openPendingTranscriptRecoveryForLastVoiceEntry() async {
    if (_entriesAfterSave.isEmpty) return;
    final entry = _lastSavedEntry!;
    final result = await PendingTranscriptRecovery.open(
      context,
      entry: entry,
      source: 'record_post_save',
      entryCount: _entriesAfterSave.length,
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(PendingTranscriptRecoveryCopy.savedSuccess),
      ),
    );
    await _finishSuccessfulCapture(result);
  }

  Future<void> _openCaptureMode(RecordCaptureMode mode) async {
    await navigateToCaptureMode(
      context,
      mode: mode,
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openFirstUseWordingOpening(FirstUseWordingPrompt prompt) async {
    await navigateToFirstUseWordingOpening(
      context,
      prompt: prompt,
      source: 'record',
      onSaved: _finishSuccessfulCapture,
    );
  }

  Future<void> _openCorrectTranscriptForEntry(JournalEntry entry) async {
    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: 'record_post_save_heard',
      entryCount: _journalEntryCount,
    );
    if (updated == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(TranscriptCorrectionCopy.savedSuccess),
      ),
    );
    await _refreshAfterTranscriptCorrection(updated);
  }

  Future<void> _refreshAfterTranscriptCorrection(JournalEntry corrected) async {
    final all = await AppServices.instance.journalStore.loadAll();
    if (!mounted) return;
    setState(() {
      _journalEntries = all;
      _journalEntryCount = all.length;
      if (_entriesAfterSave.isNotEmpty &&
          _entriesAfterSave.first.id == corrected.id) {
        _entriesAfterSave = [
          corrected,
          ..._entriesAfterSave.skip(1),
        ];
      }
    });
  }

  Future<void> _openTypedFallbackForLastVoiceEntry() async {
    await _openPendingTranscriptRecoveryForLastVoiceEntry();
  }

  Future<void> _openPostSaveMomentDetail({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required int entryCount,
  }) async {
    final saved = await PostSaveMomentDetailSheet.show(
      context,
      parentEntry: parentEntry,
      detailType: detailType,
      entryCount: entryCount,
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(PostSaveMomentDetailCopy.savedConfirmation),
      ),
    );
  }

  Future<void> _openArchiveHistory() async {
    final content = ArchiveHistoryEngine.build(entries: _journalEntries);
    if (!mounted) return;
    await ArchiveHistorySheet.show(
      context,
      content: content,
      entryCount: _journalEntryCount,
    );
  }

  JournalEntry? get _lastSavedEntry =>
      _entriesAfterSave.isNotEmpty ? _entriesAfterSave.first : null;

  bool get _lastSavedEntryIsDegraded =>
      _auditDegradedVoicePostSave ||
      VoiceCapturePostSave.showTypedFallbackPrimary(_lastSavedEntry);

  bool get _auditDegradedVoicePostSave {
    if (!VisualAuditOverrides.active) return false;
    return VisualAuditOverrides.peekRecordPresentation()?.degradedVoicePostSave ==
        true;
  }

  RecordCtaPolicyResolution _recordCtaPolicy(
    RecordUiState ui, {
    RecordingPhase? micPhase,
    MicrophonePermissionState? micPermissionState,
    bool? userDeniedThisSession,
  }) {
    final phase = micPhase ?? _mic;
    final permission = micPermissionState ?? _micPermissionState;
    // Recorder access (e.g. iOS simulator mismatch) wins over a stale denied phase.
    final effectiveMicPhase =
        permission == MicrophonePermissionState.granted ||
            permission ==
                MicrophonePermissionState.grantedWithPermissionHandlerMismatch
        ? RecordingPhase.ready
        : phase;
    final userDenied = userDeniedThisSession ?? _micPermissionUserDenied;
    return RecordCtaPolicy.resolve(
      ui: ui,
      entryCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountLoaded,
      showPostSaveLoop: _showPostSaveLoop,
      isDegradedVoiceSave: _lastSavedEntryIsDegraded,
      lastSavedEntry: _lastSavedEntry,
      micPhase: effectiveMicPhase,
      micPermissionState: permission,
      userDeniedThisSession: userDenied,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
  }

  String? _lastCtaPolicyLogLine;

  void _maybeLogRecordCtaPolicy(RecordCtaPolicyResolution resolution) {
    if (!kDebugMode) return;
    final secondary = resolution.secondaryLabels.isEmpty
        ? 'none'
        : resolution.secondaryLabels.join(',');
    final action = resolution.action?.logLabel ?? 'none';
    final line =
        'state=${resolution.state.logLabel} '
        'mic=${resolution.micPermissionState.name} '
        'primary=${resolution.primaryLabel ?? 'none'} '
        'action=$action '
        'secondary=$secondary';
    if (_lastCtaPolicyLogLine == line) return;
    _lastCtaPolicyLogLine = line;
    RecordCtaPolicy.log(resolution);
  }

  void _logMicRefreshApply(RecordMicRefreshApplyResult applied) {
    if (applied.initialDeniedCanAskAgain) {
      _recordPermissionUiLog(
        'initial deniedCanAskAgain treated_as=requestable',
      );
    }
    if (applied.userDeniedBlocked) {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    if (applied.permanentDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    }
  }

  Future<void> _refreshMic({bool fromUserRequest = false}) async {
    final resolution = await _recording.evaluateMicrophonePermission();
    final cap = resolution.phase;
    if (!mounted) return;

    if (MicrophonePermissionResolver.isRecordable(resolution.state)) {
      setState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = resolution.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
        if (resolution.state == MicrophonePermissionState.granted) {
          _ignoreStaleMicRefreshAfterGrant = true;
        }
      });
      _recordLog('state ui=$_ui mic=$cap recordable=${resolution.state.name} (refresh)');
      _maybeAutostartWithPrompt();
      return;
    }

    final applied = RecordMicrophonePermissionUi.applyMicRefresh(
      phase: cap,
      userDeniedThisSession: _micPermissionUserDenied,
      currentUi: _ui,
      ignoreAfterGrant: _ignoreStaleMicRefreshAfterGrant,
      fromUserRequest: fromUserRequest,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
    );
    if (applied.ignored) {
      _recordPermissionUiLog('stale refresh ignored after granted=true');
      return;
    }
    _logMicRefreshApply(applied);
    setState(() {
      _mic = applied.mic!;
      _micPermissionState = resolution.state;
      _micPermissionUserDenied = applied.userDenied!;
      _micSessionRequiresOpenSettings = applied.sessionRequiresOpenSettings;
      _ui = applied.ui!;
    });
    _recordLog('state ui=$_ui mic=$cap (refresh)');
    _maybeAutostartWithPrompt();
  }

  void _maybeAutostartWithPrompt() {
    if (_autostartWithPromptAttempted) return;
    if (!widget.autostartWithPrompt) return;
    if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) return;
    if (_ui != RecordUiState.ready || _mic != RecordingPhase.ready) return;
    _autostartWithPromptAttempted = true;
    unawaited(_onRecordPressed(source: 'main'));
  }

  bool _shouldHideCompetingRecordCtas(RecordUiState ui) =>
      RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
        ui: ui,
        micPhase: _mic,
        userDeniedThisSession: _micPermissionUserDenied,
      );

  bool _shouldHideCardRecordButtons(RecordUiState ui) {
    if (_shouldHideCompetingRecordCtas(ui)) return true;
    return RecordCtaPolicy.shouldHideCardRecordCtas(_recordCtaPolicy(ui));
  }

  bool _shouldPromoteMicCaptureActions(RecordCtaPolicyResolution policy) {
    return policy.showMainBottomCta &&
        policy.action != null &&
        policy.action != RecordCtaAction.startRecording;
  }

  Widget _buildCaptureEntryActions({
    required BuildContext context,
    required String? selectedPrompt,
    required RecordCtaPolicyResolution policy,
  }) {
    return CaptureEntryActions(
      onRecord: () => unawaited(_onRecordPressed(source: 'main')),
      recordButtonKey: const Key('capture_entry_record_cta'),
      typeCapturePrompt: selectedPrompt,
      onTextThoughtSaved: _finishSuccessfulCapture,
      onLogPressureMoment: () => context.push('/pressure-check-in'),
      recordButtonLabel: policy.primaryLabel,
      underRecordHelper: null,
    );
  }

  void _trackRecordCtaPressed() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.recordCtaTapped,
      entryCount: _journalEntryCount,
    );
    InviteFunnelMetrics.recordCtaTapped(entryCount: _journalEntryCount);
    if (_journalEntryCount == 0 && _dueCheckInToday == null) {
      ActivationTracker.trackActivationFirstRecordCtaTapped();
    }
    _recordLog('button pressed');
  }

  RecordCtaPolicyResolution _recordCtaPolicyForSession() {
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        return _recordCtaPolicy(
          audit.ui,
          micPhase: audit.micPhase ?? _mic,
          userDeniedThisSession:
              audit.userDeniedThisSession ?? _micPermissionUserDenied,
        );
      }
    }
    return _recordCtaPolicy(_ui);
  }

  Future<void> _onRecordPressed({required String source}) async {
    _recordCtaLog('tapped source=$source');
    final policy = _recordCtaPolicyForSession();
    final action =
        policy.action ??
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
    switch (action) {
      case RecordCtaAction.startRecording:
        _recordCtaLog('start_recording=true');
        _trackRecordCtaPressed();
        setState(() {
          _error = null;
          _localSaveTitle = null;
          _syncNote = null;
          _seconds = 0;
          _showPostSaveLoop = false;
          _postSaveFollowUp = null;
          EntryAboutnessSession.clearSaveReceipt();
          MemorySurfacingSession.clearSaveReceipts();
          PreserveOriginalSession.clearSaveReceipt();
          ConfirmedRepeatTriggerCapture.clearSaveReceipt();
          ConfirmedRepeatHelpfulActionCapture.clearSaveReceipt();
        });
        await _beginRecording();
      case RecordCtaAction.requestPermission:
        _trackRecordCtaPressed();
        await _requestPermissionAndRecord();
      case RecordCtaAction.openSettings:
        _recordCtaLog('open_settings=true');
        await _openMicSettings();
      case RecordCtaAction.routeToBlockedPanel:
        final stateLabel = RecordMicrophonePermissionUi.micBlockedStateLabel(
          micPhase: _mic,
          userDeniedThisSession: _micPermissionUserDenied,
        );
        _recordCtaLog('blocked_by_permission state=$stateLabel');
        if (policy.micPermissionState ==
                MicrophonePermissionState.deniedOpenSettings ||
            _mic == RecordingPhase.permissionPermanentlyDenied ||
            _micSessionRequiresOpenSettings ||
            _micPermissionUserDenied) {
          await _openMicSettings();
        } else {
          await _routeToPermissionPanel();
        }
    }
  }

  Future<void> _routeToPermissionPanel() async {
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ignoreStaleMicRefreshAfterGrant = false;
        _ui = RecordUiState.permissionBlocked;
        if (_mic == RecordingPhase.permissionPermanentlyDenied) {
          _micPermissionUserDenied = true;
        }
        _error = null;
      });
    }
    _recordCtaLog('routed_to_permission_panel=true');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final panelContext = _permissionPanelKey.currentContext;
      if (panelContext != null) {
        Scrollable.ensureVisible(
          panelContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  Future<void> _requestMic() async {
    _recordLog('button pressed (allow microphone)');
    final existing = await _recording.evaluateMicrophonePermission();
    if (existing.isRecordable) {
      if (!mounted) return;
      setState(() {
        _mic = RecordingPhase.ready;
        _micPermissionState = existing.state;
        _micPermissionUserDenied = false;
        _micSessionRequiresOpenSettings = false;
        _ui = RecordUiState.ready;
      });
      _recordPermissionUiLog(
        'recorder_verified=${existing.state.name} start_recording=true',
      );
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionRequested();
    }
    _recordPermissionUiLog('request started');
    setState(() => _ui = RecordUiState.requestingPermission);
    await _recording.requestMicrophone();
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  Future<void> _requestPermissionAndRecord() async {
    setState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _seconds = 0;
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      EntryAboutnessSession.clearSaveReceipt();
      MemorySurfacingSession.clearSaveReceipts();
      PreserveOriginalSession.clearSaveReceipt();
      _ui = RecordUiState.requestingPermission;
    });
    _recordPermissionUiLog('request started');

    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionRequested();
    }
    var cap = await _recording.checkMicrophone();
    _recordLog('permission result $cap');
    if (cap != RecordingPhase.ready) {
      final resolution = await _recording.evaluateMicrophonePermission();
      if (resolution.isRecordable) {
        cap = RecordingPhase.ready;
        if (!mounted) return;
        setState(() {
          _mic = RecordingPhase.ready;
          _micPermissionState = resolution.state;
          _micPermissionUserDenied = false;
          _micSessionRequiresOpenSettings = false;
          _ui = RecordUiState.ready;
        });
      } else if (!await MicrophonePermissionEnvironment.shouldSkipPermissionRequest(
        status: resolution.permissionHandlerStatus ?? PermissionStatus.denied,
        hasRecorder: resolution.hasRecorder,
      )) {
        await _recording.requestMicrophone();
        _recordLog('permission result after request');
      } else {
        cap = await _recording.checkMicrophone();
        _recordLog('permission result after skip-request $cap');
      }
    }
    if (!mounted) return;
    await _refreshMic(fromUserRequest: true);
    if (!mounted) return;
    if (_mic == RecordingPhase.ready) {
      _recordCtaLog('start_recording=true');
      _recordPermissionUiLog('request result=granted start_recording=true');
      await _beginRecording();
      return;
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialMicPermissionDenied();
    }
    if (_mic == RecordingPhase.permissionPermanentlyDenied) {
      _recordPermissionUiLog('permanent_denied=true show_open_settings=true');
    } else {
      _recordPermissionUiLog('user_denied=true show_blocked=true');
    }
    _recordPermissionUiLog('request result=denied show_blocked=true');
    _recordLog('start failed — permission not granted');
    RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    if (_ui != RecordUiState.permissionBlocked) {
      setState(() {
        _ui = RecordUiState.permissionBlocked;
        _micSessionRequiresOpenSettings = true;
      });
    } else {
      setState(() => _micSessionRequiresOpenSettings = true);
    }
    await _routeToPermissionPanel();
  }

  Future<void> _beginRecording() async {
    _recordLog('start requested');
    try {
      await _recording.startRecording(permissionVerified: true);
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.recording;
        _stageLabel = 'Recording…';
        _mic = RecordingPhase.ready;
      });
      if (TrialMode.enabled) {
        await ActivationTracker.trackTrialRecordingStarted();
      }
      unawaited(FirstLoopActivationCoordinator.markRecordingStarted());
      if (_dueCheckInToday != null) {
        unawaited(
          ReturnDayFrictionCoordinator.markRecordingStarted(
            _dueCheckInToday!.id,
          ),
        );
      }
      _recordLog('start success');
      _recordLog('state ui=$_ui (recording)');
    } on RecordingException catch (e) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed ${e.message}');
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    } catch (e, st) {
      _ignoreStaleMicRefreshAfterGrant = false;
      _recordLog('start failed $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      if (!mounted) return;
      setState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    }
  }

  Future<void> _stopAndProcess() async {
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveStarted();
    }
    setState(() {
      _ui = RecordUiState.processing;
      _stageLabel = 'Stopping…';
    });
    try {
      final result = await _recording.stopRecording();
      _lastCaptureLikelySilentInput = result.likelySilentInput;
      setState(() => _stageLabel = 'Attesting device…');
      final pipelineResult = await _pipeline.run(
        audioFile: result.file,
        durationSeconds: result.durationSeconds,
        onStage: (stage) {
          if (!mounted) return;
          setState(() {
            _pipelineStage = stage;
            _stageLabel = switch (stage) {
              PipelineStage.attesting => 'Uploading audio…',
              PipelineStage.transcribing => 'Transcribing…',
              PipelineStage.analyzing => 'Finding patterns…',
              PipelineStage.saving => 'Saving…',
              PipelineStage.done => 'Done',
            };
          });
        },
      );
      if (!mounted) return;
      await _finishSuccessfulCapture(pipelineResult);
    } on CapturePipelineFailure catch (e) {
      if (e.message == VoiceCaptureCopy.notEnoughAudio) {
        setState(() {
          _ui = RecordUiState.ready;
          _error = e.message;
          _localSaveTitle = null;
          _syncNote = null;
          _stageLabel = '';
        });
        return;
      }
      setState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.saveFailed;
        _localSaveTitle = null;
        _syncNote = null;
      });
    } on RecordingException catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.recordingFailed;
      });
    } catch (e) {
      setState(() {
        _ui = RecordUiState.error;
        _error = VoiceCaptureCopy.saveFailed;
        _localSaveTitle = null;
        _syncNote = null;
      });
    }
  }

  Future<void> _finishSuccessfulCapture(
    CapturePipelineResult pipelineResult,
  ) async {
    final savedFromTriggerPrompt = ConfirmedRepeatTriggerCapture.resolveSave(
      capturePrompt: _selectedPromptLine,
    );
    final savedFromHelpfulActionPrompt = savedFromTriggerPrompt
        ? false
        : ConfirmedRepeatHelpfulActionCapture.resolveSave(
            capturePrompt: _selectedPromptLine,
          );
    final all = await AppServices.instance.journal.loadAll();
    final movement = ArchiveMovementEngine.build(
      all,
      newEntryId: pipelineResult.entry.id,
    );
    final cloudOk = pipelineResult.syncSucceeded;
    final savedEntry = pipelineResult.entry;
    final hasSavedTranscript =
        VoiceCaptureQuality.hasUsableSpokenText(savedEntry);
    final state = buildArchiveStateObjectV3(entries: all);
    final priorEntries = all.length > 1
        ? all.sublist(1)
        : const <JournalEntry>[];
    final instantResponse = const InstantReflectionResponseEngine().respond(
      entry: pipelineResult.entry,
      priorEntries: priorEntries,
    );

    final prefs = AppServices.instance.prefs;
    final discoveryFuture = const DailyDiscoveryEngine()
        .detectImmediateDiscovery(
          store: DailyDiscoveryStore(prefs),
          entries: all,
          state: state,
        );
    final evolutionFuture = const ArchiveEvolutionCoordinator()
        .detectAfterRecording(entries: all, state: state);
    final completedCheckIn = await TomorrowCheckInCoordinator.completeAfterSave(
      entries: all,
    );
    final patternMemory = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadActive()
        : null;
    final patternProgress = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestProgress()
        : null;
    final patternNextAction = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestNextAction()
        : null;
    final habitProof = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestHabitProof()
        : null;
    final weeklyRecap = completedCheckIn != null
        ? await PatternMemoryCoordinator.loadLatestWeeklyRecap()
        : null;
    final canShareRecap =
        completedCheckIn != null &&
        (weeklyRecap != null ||
            patternProgress != null ||
            (patternMemory != null && patternMemory.checkInCount >= 2));
    final shareRecap = canShareRecap
        ? await PatternMemoryCoordinator.buildShareRecap()
        : null;

    final latestReflectionText = resolveEntryDisplayText(savedEntry).text.isNotEmpty
        ? resolveEntryDisplayText(savedEntry).text
        : savedEntry.transcript;
    // Detect reflection language so post-save cards can speak the same
    // language. Screenshot mode forces a language for marketing captures.
    final detected = ScreenshotMode.language != null
        ? DetectedLanguage.userSelected(ScreenshotMode.languageCode)
        : detectReflectionLanguage(latestReflectionText);
    final languageCode = detected.uiLanguageCode;
    unawaited(
      ReflectionLanguageStore(
        AppServices.instance.prefs,
      ).recordDetection(detected, originalText: latestReflectionText),
    );
    final inputQuality = assessReflectionQuality(latestReflectionText);
    unawaited(
      InputQualityStore(
        AppServices.instance.prefs,
      ).recordAssessment(inputQuality),
    );

    if (!mounted) return;
    setState(() {
      _ui = RecordUiState.done;
      _entriesAfterSave = all;
      // First 60 Seconds: usable first entry only — degraded voice waits for typed recovery.
      _recordReturnProJustSaved =
          all.length == 1 &&
          !VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry);
      _archiveStateAfterSave = state;
      _inputQuality = inputQuality;
      _inputQualityText = latestReflectionText;
      _inputQualityResolved = false;
      _languageCode = languageCode;
      _detectedLanguageCode = languageCode;
      _instantReflectionResponse = instantResponse;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = true;
      _postSaveEvolution = null;
      _archiveEvolutionLoading = true;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _firstSessionPattern = null;
      _firstSessionAlternativeIndex = 0;
      _completedCheckInToday = completedCheckIn;
      _patternMemory = patternMemory;
      _patternProgress = patternProgress;
      _patternNextAction = patternNextAction;
      _habitProof = habitProof;
      _weeklyRecap = weeklyRecap;
      _shareRecap = shareRecap;
      _dueCheckInToday = completedCheckIn != null ? null : _dueCheckInToday;
      _trackInstantReflectionSurfaced(instantResponse);
      _error = null;
      if (VoiceCaptureQuality.isDegradedVoiceCapture(savedEntry)) {
        _localSaveTitle = null;
        _syncNote = null;
        _stageLabel = VoiceCaptureCopy.savedLocallyPendingTitle;
      } else if (!cloudOk && hasSavedTranscript && !pipelineResult.analysisSucceeded) {
        _localSaveTitle = VoiceCaptureCopy.recordingSavedTitle;
        _syncNote = VoiceCaptureCopy.analysisUnavailableNote;
        _stageLabel = VoiceCaptureCopy.recordingSavedTitle;
      } else {
        _localSaveTitle = cloudOk
            ? null
            : CaptureSaveMessages.savedPrivatelyOnDevice;
        _syncNote = cloudOk
            ? null
            : ConsumerCopyGuard.userFacingSyncNote(pipelineResult.syncNote) ??
                  CaptureSaveMessages.addAnotherMomentTomorrow;
        _stageLabel = cloudOk
            ? 'Saved'
            : CaptureSaveMessages.savedPrivatelyOnDevice;
      }
      if (pipelineResult.attachedTypedTextToVoiceEntry) {
        RecordPipelineLog.typedFallbackInsightShown();
      }
      _archiveMovement = movement;
      _journalEntryCount = all.length;
      _journalEntryCountLoaded = true;
      _journalEntries = all;
      _entryDates = all.map((e) => e.createdAt).toList();
      _firstArchiveMilestoneCompleted =
          ExamplePromptVisibility.hasCompletedFirstArchiveMilestone(all);
      _showPostSaveLoop = cloudOk;
      _lastCaptureAnalysisSucceeded = pipelineResult.analysisSucceeded;
      _lastCaptureLowQualityTranscript = pipelineResult.lowQualityTranscript;
      _postSaveFollowUp = null;
      _savedFromConfirmedRepeatTrigger =
          EarlyFirstSignalEngine.buildTriggerCapturePayoff(
                entries: all,
                savedFromTriggerPrompt: savedFromTriggerPrompt,
              ) !=
              null;
      _savedFromHelpfulAction = !savedFromTriggerPrompt &&
          EarlyFirstSignalEngine.buildHelpfulActionPayoff(
                entries: all,
                savedFromHelpfulActionPrompt: savedFromHelpfulActionPrompt,
              ) !=
              null;
    });

    if (_savedFromConfirmedRepeatTrigger) {
      unawaited(EarlyEvidenceMilestoneStore.instance().markTriggerCaptured());
      if (mounted) setState(() => _earlyEvidenceTriggerCaptured = true);
    }
    if (_savedFromHelpfulAction) {
      unawaited(
        EarlyEvidenceMilestoneStore.instance().markHelpfulActionCaptured(),
      );
      if (mounted) setState(() => _earlyEvidenceHelpfulCaptured = true);
    }

    unawaited(_handleSuggestionAttributionAfterSave(all.length));
    unawaited(_buildDoneForTodayReceipt());

    // Keep a long-term Key Moment so this reflection (or closed loop) is easy
    // to find again by day. Original text is preserved verbatim.
    unawaited(
      KeyMomentCoordinator.captureAfterSave(
        reflectionText: latestReflectionText,
        patternTitle: completedCheckIn?.patternTitle,
        resultHint: completedCheckIn?.selectedOption?.comparisonHint,
        nextCheck: completedCheckIn?.question,
        languageCode: languageCode,
        source: completedCheckIn != null
            ? KeyMomentSource.checkIn
            : KeyMomentSource.reflection,
      ),
    );

    final discovery = await discoveryFuture;
    final evolution = await evolutionFuture;
    final returnLoop =
        await TomorrowReturnLoopCoordinator.persistAfterRecording(
          all,
          immediateDiscovery: discovery,
        );

    final eligibleCount = all
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .length;
    await ActivationTracker.trackReflectionMilestones(eligibleCount);
    unawaited(LoopModeCoordinator.onRecordingSaved());
    await ReturnReasonCaptureCoordinator.onReflectionSaved(
      eligibleCount: eligibleCount,
      lastReflectionAt: _lastReflectionAt,
    );
    if (eligibleCount == 1) {
      ActivationTracker.trackActivationFirstSaveCompleted();
    }
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveCompleted();
    }

    // Return day: recording a moment after answering closes the loop.
    if (completedCheckIn != null) {
      await ReturnDayFrictionCoordinator.markMomentSaved(completedCheckIn.id);
      await ReturnDayFrictionCoordinator.markLoopClosed(completedCheckIn.id);
    }

    FirstLoopActivationState? firstLoopAfterSave;
    if (all.isNotEmpty) {
      firstLoopAfterSave =
          await FirstLoopActivationCoordinator.markFirstMomentSaved();
    }

    final firstSession = await FirstSessionCoordinator.isFirstSession(
      reflectionCount: all.length,
    );
    FirstSessionPattern? firstPattern;
    final latestHasComparableText = all.isNotEmpty &&
        !ComparableEvidenceText.entryHasPendingTranscript(all.last);
    if (firstSession && all.isNotEmpty && latestHasComparableText) {
      firstPattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      firstLoopAfterSave =
          await FirstLoopActivationCoordinator.markFirstPatternShown(
            firstPattern.title,
          );
    }

    ReturnComparison? comparison;
    ReturnStreak? streak;
    WatchForItem? completedWatch;
    WatchForItem? suggestedWatch;
    ActivePatternThread? activeThread;
    SecondSessionComparison? secondComparison;
    FirstSessionPattern? postSavePattern;
    PatternHypothesis? patternHypothesis;

    if (firstSession && all.isNotEmpty && latestHasComparableText) {
      postSavePattern = firstPattern;
    } else if (all.isNotEmpty && latestHasComparableText) {
      postSavePattern = await FirstSessionCoordinator.buildFromEntry(
        all.last,
        alternativeIndex: _firstSessionAlternativeIndex,
      );
      if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive &&
          const SecondSessionSignalEngine().hasGroundedRepeatMatch(all)) {
        secondComparison = const SecondSessionSignalEngine().build(all);
      }
    }
    if (all.length >= FirstThreeSessionGates.minEntriesForUsefulArchive &&
        ArchiveEvidenceQualityGate.allowsPatternHypothesis(all)) {
      patternHypothesis = await const PatternHypothesisEngine().build(all);
    }

    final postSaveFeedback = await SignalFeedbackStore.instance().loadAll();
    final postSaveSelected = await SelectedSignalCoordinator.loadCurrent();

    if (firstSession) {
      activeThread = await ActivePatternThreadCoordinator.loadCurrentThread();
    } else {
      completedWatch = await WatchForCoordinator.completePendingAfterSave(
        entries: all,
      );
      comparison = await ReturnComparisonCoordinator.buildAfterSaveIfDue(
        entries: all,
        loop: returnLoop,
      );
      suggestedWatch = returnLoop != null
          ? WatchForCoordinator.buildSuggestedWatchForAfterSave(
              entries: all,
              loop: returnLoop,
              signals: ArchiveBeliefsPresenter.potentialSignalsFromEntry(
                all.last,
              ),
              alternativeIndex: _watchForAlternativeIndex,
            )
          : null;
      streak = comparison != null
          ? await ReturnRetentionCoordinator.loadStreak()
          : null;
      activeThread = completedWatch != null
          ? await ActivePatternThreadCoordinator.loadCurrentThread()
          : await ActivePatternThreadCoordinator.loadCurrentThread();
    }

    if (!mounted) return;
    setState(() {
      _immediateDiscovery = discovery;
      _immediateDiscoveryLoading = false;
      _postSaveEvolution = evolution;
      _archiveEvolutionLoading = false;
      _isFirstSessionPostSave = firstSession;
      _firstSessionPattern = firstPattern;
      _postSavePattern = postSavePattern ?? firstPattern;
      _postSaveInsightFeedback = postSaveFeedback;
      _postSaveSelectedSignal = postSaveSelected;
      _secondSessionComparison = secondComparison;
      _patternHypothesis = patternHypothesis;
      _patternHypothesisDismissed = false;
      _firstLoopJustReady = false;
      _returnDayJustClosed = completedCheckIn != null;
      if (firstLoopAfterSave != null) {
        _firstLoop = firstLoopAfterSave;
      }
      if (TrialMode.enabled && firstSession && firstPattern != null) {
        _watchForAcceptPending = true;
        unawaited(ActivationTracker.markWatchForAcceptPending());
      }
      _returnComparison = comparison;
      _returnStreak = streak;
      _tomorrowReturnLoop = returnLoop;
      _completedWatchForToday = completedWatch;
      _suggestedWatchForTomorrow = suggestedWatch;
      _pendingWatchForToday = null;
      _activePatternThread = activeThread;
      if (returnLoop != null) {
        _postSaveFollowUp = returnLoop.watchForNextTime;
      }
      if (evolution != null) {
        _localSaveTitle = null;
        _stageLabel = '';
      }
    });
    ProductAnalytics.trackStrings('immediate_discovery_surfaced', {
      'has_discovery': discovery != null ? 'yes' : 'no',
      if (discovery != null) 'type': discovery.type.name,
    });
    ProductAnalytics.trackStrings('archive_evolution_after_recording', {
      'has_evolution': evolution != null ? 'yes' : 'no',
      if (evolution != null) 'kind': evolution.kind.name,
    });
    await _loadFirstThreeJourney();
    unawaited(_loadSignalArchive());
  }

  void _trackInstantReflectionSurfaced(InstantReflectionResponse? response) {
    ProductAnalytics.trackStrings('instant_reflection_surfaced', {
      'has_response': response != null ? 'yes' : 'no',
      if (response != null) 'signal': response.signal.name,
    });
  }

  /// True when the just-saved reflection is weak and the user has not yet
  /// added a sentence or chosen to use it anyway. Gates the pattern/result so
  /// the coach is the first thing shown. One sharpening prompt per reflection.
  bool get _showInputQualityCoach =>
      _inputQuality != null &&
      _inputQuality!.shouldAskForSharpening &&
      !_inputQualityResolved;

  bool get _applyEmptyArchiveGates => !ScreenshotMode.enabled;

  bool get _journalEntryCountReady =>
      _journalEntryCountLoaded || ScreenshotMode.enabled;

  void _logRecordEmptyGate([String reason = 'build']) {
    if (kDebugMode) {
      debugPrint(
        'record_empty_gate entryCount=$_journalEntryCount '
        'loaded=$_journalEntryCountLoaded reason=$reason',
      );
    }
  }

  bool get _canShowArchiveProgressCards =>
      RecordEmptyArchiveGates.allowArchiveProgressUi(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      ) ||
      !_applyEmptyArchiveGates;

  DailyMirrorResult get _dailyMirror {
    if (!_journalEntryCountReady) return DailyMirrorResult.empty;
    return const DailyMirrorEngine().build(_journalEntries);
  }

  bool get _showDailyMirrorCard =>
      _applyEmptyArchiveGates &&
      RecordEmptyArchiveGates.showDailyMirrorCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _isPostSaveSurface =>
      _ui == RecordUiState.done || _showPostSaveLoop;

  bool get _showFirstRunPrivacyReassurance {
    if (CreatorDemoMode.isActive) return false;
    if (ScreenshotMode.enabled) {
      return ScreenshotMode.recordCleanFirstRunPreview &&
          _journalEntryCount == 0 &&
          !_isPostSaveSurface;
    }
    return RecordEmptyArchiveGates.showFirstRunPrivacyReassurance(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isPostSave: _isPostSaveSurface,
    );
  }

  bool get _showReadyToRecordStatus =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showReadyToRecordStatus(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showArchiveContextPrompts =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showArchiveContextPrompts(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showFirstThreeJourneyOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showFirstThreeJourneyCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showRetentionJourneyCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showRetentionJourneyCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showTwoDayActivationCard =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showTwoDayActivationCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showLegacyEmptyOnboarding =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showLegacyEmptyOnboarding(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _showCurrentObjectiveOnRecord =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showCurrentObjectiveCard(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  bool get _suppressRecordRetentionForEarlyProof {
    if (!_journalEntryCountReady || _isPostSaveSurface) return false;
    if (!RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isPostSave: false,
    )) {
      return false;
    }
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_journalEntries);
  }

  bool get _showBottomRetentionCards =>
      !_suppressRecordRetentionForEarlyProof &&
      (!_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showBottomRetentionCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      ));

  bool get _showAhaMomentCards =>
      !_applyEmptyArchiveGates ||
      RecordEmptyArchiveGates.showAhaMomentCards(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );

  RecordStackDecision _recordStackDecision(RecordUiState ui) {
    final hasDueCheck =
        _dueCheckInToday != null &&
        (ui == RecordUiState.ready || ui == RecordUiState.recording);
    final hasSavedReflection =
        ui == RecordUiState.done && _entriesAfterSave.isNotEmpty;
    final hasCompletedResult =
        _completedCheckInToday != null && !_returnDayJustClosed;
    final hasResultNextCheck = hasCompletedResult && !_showInputQualityCoach;
    final hasArchiveProof =
        _patternMemory != null ||
        _patternProgress != null ||
        _patternNextAction != null ||
        _habitProof != null ||
        _weeklyRecap != null ||
        _shareRecap != null;
    final readyNotPostSave =
        ui == RecordUiState.ready || ui == RecordUiState.recording;
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final hasRetentionCard = _shouldShowRetentionOnRecord(
      retentionState,
      readyNotPostSave: readyNotPostSave,
      hasDueCheck: hasDueCheck,
      hasResultNextCheck: hasResultNextCheck,
    );

    final returnDay = const ReturnDayJourneyEngine().evaluate(
      journey: _signalJourney,
      reflectionCount: _journalEntryCount,
      now: DateTime.now(),
      lastReflectionAt: _lastReflectionAt,
    );

    return decideRecordStack(
      hasDueCheck: hasDueCheck,
      isFirstRun: _journalEntryCountReady && _journalEntryCount == 0,
      reflectionCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountReady,
      isTrialMode: TrialMode.enabled,
      isRecording: ui == RecordUiState.recording,
      hasSavedReflection: hasSavedReflection,
      inputQualityNeedsCoach: _showInputQualityCoach,
      hasCompletedResult: hasCompletedResult,
      hasResultNextCheck: hasResultNextCheck,
      hasRoutineAnchorOffer: hasResultNextCheck,
      hasArchiveProof: hasArchiveProof,
      archiveMemoryDemoEligible: !TrialMode.enabled,
      hasRetentionStateCard: hasRetentionCard,
      suppressRetentionForFirstRunDemo:
          retentionState.type == RetentionStateType.noCheckSet,
      suppressRetentionForPostSaveNextCheck:
          retentionState.type == RetentionStateType.loopClosed &&
          hasResultNextCheck,
      showReturnDayJourney:
          returnDay.showCard && readyNotPostSave && !hasDueCheck,
    );
  }

  CurrentObjective _buildCurrentObjective({required bool readyNotPostSave}) {
    final retentionState = _buildRetentionState(
      readyNotPostSave: readyNotPostSave,
    );
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildCurrentObjective(
      retentionState: retentionState,
      activeCheckIn: _dueCheckInToday ?? _activeCheckInForTomorrow,
      hasAnyMoment: _journalEntryCount > 0,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasNextCheckChosen: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
    );
  }

  void _onCurrentObjectivePrimary(CurrentObjective objective) {
    switch (objective.type) {
      case CurrentObjectiveType.recordFirstMoment:
      case CurrentObjectiveType.recordAnyMoment:
      case CurrentObjectiveType.answerTodayCheck:
      case CurrentObjectiveType.chooseNextCheck:
        unawaited(_onRecordPressed(source: 'moment'));
      case CurrentObjectiveType.doneForToday:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _currentObjectiveWidget(RecordStackDecision stack) {
    if (ScreenshotMode.enabled) {
      if (ScreenshotMode.objectiveDueCheckPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveDueCheckSample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveFirstMomentPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveFirstMomentSample,
          onPrimaryTap: () => unawaited(_onRecordPressed(source: 'moment')),
          persistSnapshot: false,
        );
      }
      if (ScreenshotMode.objectiveNextReadyPreview) {
        return CurrentObjectiveCard(
          objective: ScreenshotSampleData.objectiveNextReadySample,
          onPrimaryTap: () {},
          persistSnapshot: false,
        );
      }
    }
    if (!stack.showCurrentObjectiveCard) return null;
    final objective = _buildCurrentObjective(
      readyNotPostSave:
          _ui == RecordUiState.ready || _ui == RecordUiState.recording,
    );
    return CurrentObjectiveCard(
      objective: objective,
      onPrimaryTap: () => _onCurrentObjectivePrimary(objective),
      persistSnapshot: !ScreenshotMode.enabled,
      showRecordCta: !_shouldHideCardRecordButtons(_ui),
    );
  }

  RetentionState _buildRetentionState({required bool readyNotPostSave}) {
    final active = _dueCheckInToday ?? _activeCheckInForTomorrow;
    final missed = _missedCheckInForDiagnosis == null
        ? _recentMissedCheckIn
        : null;
    final loopClosed =
        _completedCheckInToday != null &&
        !_returnDayJustClosed &&
        _activeCheckInForTomorrow == null &&
        _dueCheckInToday == null;
    return buildRetentionState(
      now: DateTime.now(),
      activeCheckIn: active,
      missedCheckIn: missed,
      hasClosedLoopToday: loopClosed && readyNotPostSave,
      hasChosenNextCheck: _retentionNextCheckJustChosen,
      latestNextCheck:
          _activeCheckInForTomorrow?.question ??
          _completedCheckInToday?.tomorrowsBetterQuestion,
      latestPatternTitle:
          _activeCheckInForTomorrow?.patternTitle ??
          _completedCheckInToday?.patternTitle,
      compact:
          _retentionNextCheckJustChosen ||
          (_activeCheckInForTomorrow != null && _dueCheckInToday == null),
    );
  }

  bool _shouldShowRetentionOnRecord(
    RetentionState state, {
    required bool readyNotPostSave,
    required bool hasDueCheck,
    required bool hasResultNextCheck,
  }) {
    if (_retentionDismissed &&
        state.type == RetentionStateType.nextCheckChosen) {
      return false;
    }
    if (state.type == RetentionStateType.checkDueToday && hasDueCheck) {
      return false;
    }
    if (state.type == RetentionStateType.checkMissed &&
        _missedCheckInForDiagnosis != null) {
      return false;
    }
    if (state.type == RetentionStateType.loopClosed && hasResultNextCheck) {
      return false;
    }
    if (state.type == RetentionStateType.nextCheckChosen &&
        _retentionNextCheckJustChosen) {
      return true;
    }
    return readyNotPostSave;
  }

  void _onRetentionPrimaryTap(RetentionState state) {
    switch (state.type) {
      case RetentionStateType.noCheckSet:
      case RetentionStateType.checkMissed:
        unawaited(_onRecordPressed(source: 'moment'));
      case RetentionStateType.checkDueToday:
      case RetentionStateType.checkSetForTomorrow:
        break;
      case RetentionStateType.loopClosed:
        break;
      case RetentionStateType.nextCheckChosen:
        setState(() => _retentionDismissed = true);
    }
  }

  Widget? _retentionCardWidget(RecordStackDecision stack) {
    if (!stack.showRetentionStateCard) return null;
    final state = _buildRetentionState(
      readyNotPostSave:
          _ui == RecordUiState.ready ||
          _ui == RecordUiState.recording ||
          _retentionNextCheckJustChosen,
    );
    final compelling = state.checkQuestion != null
        ? buildCompellingCheck(
            baseQuestion: state.checkQuestion!,
            patternTitle: state.patternTitle,
          )
        : null;
    return RetentionStateCard(
      state: state,
      checkWhyThisCheck: compelling?.whyThisCheck,
      checkExampleAnswer: compelling?.exampleAnswer,
      onPrimaryTap: () => _onRetentionPrimaryTap(state),
      onDismiss: () => setState(() => _retentionDismissed = true),
    );
  }

  bool get _weakInput =>
      _inputQuality != null && _inputQuality!.shouldAskForSharpening;

  /// First-session pattern only earns a kinder angle for the harder, more
  /// self-directed triggers; quieter signals stay out of the way.
  KinderAngleTrigger? get _firstSessionKinderTrigger {
    final trigger = detectKinderAngleTrigger(_inputQualityText.trim());
    const allowed = {
      KinderAngleTrigger.selfBlame,
      KinderAngleTrigger.pressure,
      KinderAngleTrigger.tiredness,
    };
    return allowed.contains(trigger) ? trigger : null;
  }

  void _onInputQualityUseAnyway() {
    setState(() => _inputQualityResolved = true);
    unawaited(
      InputQualityStore(AppServices.instance.prefs).recordAcceptedWeak(),
    );
  }

  void _onLanguageSelected(String code) {
    if (code == _languageCode) return;
    setState(() => _languageCode = code);
    if (AppServices.isInitialized) {
      unawaited(
        ReflectionLanguageStore(
          AppServices.instance.prefs,
        ).recordOverride(code),
      );
    }
  }

  Future<void> _onInputQualityAddSentence(String combinedText) async {
    final quality = assessReflectionQuality(combinedText);
    final store = InputQualityStore(AppServices.instance.prefs);
    await store.recordSharpened();
    await store.recordAssessment(quality);
    if (!mounted) return;
    setState(() {
      _inputQuality = quality;
      _inputQualityText = combinedText;
      _inputQualityResolved = true;
    });
  }

  Future<void> _saveNextEvidencePrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    final selected = await SelectedSignalCoordinator.loadCurrent();
    final objective = CurrentObjective(
      type: CurrentObjectiveType.recordAnyMoment,
      title: ConsumerUiCopy.postSaveInsightRecordThisNext,
      body: trimmed,
      checkQuestion: trimmed,
      patternTitle: selected?.title,
      primaryCtaLabel: ConsumerUiCopy.postSaveInsightUseThisPrompt,
      route: '/record',
    );
    await CurrentObjectiveSnapshotStore.instance().saveSnapshot(objective);
    if (!mounted) return;
    setState(() => _nextEvidencePrompt = trimmed);
  }

  void _keepRecording({String? nextEvidencePrompt}) {
    setState(() {
      _showPostSaveLoop = false;
      _returnDayJustClosed = false;
      _inputQuality = null;
      _inputQualityText = '';
      _inputQualityResolved = false;
      _languageCode = ScreenshotMode.languageCode;
      _detectedLanguageCode = ScreenshotMode.languageCode;
      _instantReflectionResponse = null;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = false;
      _postSaveEvolution = null;
      _archiveEvolutionLoading = false;
      if (_postSaveFollowUp != null) {
        _selectedPromptLine = _postSaveFollowUp;
      }
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _returnComparison = null;
      _returnStreak = null;
      _completedWatchForToday = null;
      _suggestedWatchForTomorrow = null;
      _watchForAlternativeIndex = 0;
      _activePatternThread = null;
      _isFirstSessionPostSave = false;
      _firstSessionPattern = null;
      _postSavePattern = null;
      _secondSessionComparison = null;
      _patternHypothesis = null;
      _patternHypothesisDismissed = false;
      _firstSessionAlternativeIndex = 0;
      _localSaveTitle = null;
      _syncNote = null;
      _archiveMovement = null;
      _nextEvidencePrompt = nextEvidencePrompt?.trim().isNotEmpty == true
          ? nextEvidencePrompt!.trim()
          : null;
      _ui = _uiForMicPhase(_mic);
    });
  }

  Future<void> _applyAcquisitionIntentPrompt() async {
    if (widget.initialPrompt?.trim().isNotEmpty == true) return;
    if (_journalEntryCount > 0) return;
    final store = AudienceWedgeStore.instance();
    final wedge = await store.load();
    final loop = await LoopModeCoordinator.loadActive();
    final prompt = loop?.activePrompt.isNotEmpty == true
        ? loop!.activePrompt
        : await store.firstRecordingPrompt();
    if (!mounted) return;
    setState(() {
      _audienceWedge = wedge;
      _activeLoop = loop;
      if (_selectedPromptLine == null || _selectedPromptLine!.isEmpty) {
        _selectedPromptLine = prompt;
      }
    });
    if (prompt.isNotEmpty) {
      unawaited(FirstInsightSpecificityStore.markFirstPromptUsed());
      if (loop != null) {
        unawaited(LoopModeCoordinator.markFirstPromptUsed());
      }
    }
  }

  Future<void> _onSecondSessionEvidence(String prompt) async {
    _keepRecording(nextEvidencePrompt: prompt);
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null) {
      unawaited(
        NextEvidenceReminderService.schedule(
          journeyId: journey.id,
          prompt: prompt,
        ),
      );
    }
    if (mounted) {
      unawaited(
        maybeOfferReminderPrePrompt(
          context,
          trigger: ReminderPrePromptTrigger.secondRecordingComparison,
        ),
      );
    }
  }

  List<String> _postSaveSignals() {
    if (_entriesAfterSave.isEmpty) return const [];
    return ArchiveBeliefsPresenter.potentialSignalsFromEntry(
      _lastSavedEntry!,
    );
  }

  bool _postSaveShowsPossiblePattern() {
    if (_immediateDiscovery != null) return true;
    if (_postSaveSignals().isNotEmpty) return true;
    final noticed = _tomorrowReturnLoop?.noticedToday.toLowerCase() ?? '';
    return noticed.contains('pattern') || noticed.contains('forming');
  }

  void _enoughForNow() {
    if (TrialMode.enabled && _watchForAcceptPending) {
      unawaited(
        ActivationTracker.trackTrialClosedBeforeWatchForAcceptedIfPending(),
      );
      _watchForAcceptPending = false;
    }
    setState(() {
      _showPostSaveLoop = false;
      _postSaveFollowUp = null;
      _saveReceipt = null;
      _suggestionProNudgeSource = null;
      _doneForTodayReceipt = null;
      _dayTwoReturnPreview = null;
      _offerDayTwoReminder = false;
      _recordReturnProJustSaved = false;
      _archiveProofCounter = null;
      _shareableProof = null;
      _valueMomentBridge = null;
      _showEvidenceContextTag = false;
      _tomorrowReturnLoop = null;
      _localSaveTitle = null;
      _syncNote = null;
      _archiveMovement = null;
      _ui = _uiForMicPhase(_mic);
    });
    context.go('/archive-belief');
  }

  void _goToRecordTab() {
    _resetPostSaveToReady();
    context.go('/record');
  }

  void _handleReturningUserTodayAction(ReturningUserTodayAction action) {
    switch (action) {
      case ReturningUserTodayAction.addMoment:
        _goToRecordTab();
      case ReturningUserTodayAction.viewArchive:
        context.go('/archive-belief');
      case ReturningUserTodayAction.viewEvidence:
        context.push(BeliefEvidenceNavigation.route);
      case ReturningUserTodayAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
    }
  }

  void _handleNextMomentPromptAction(NextMomentPromptAction action) {
    switch (action) {
      case NextMomentPromptAction.addMoment:
        _goToRecordTab();
      case NextMomentPromptAction.viewEvidence:
        context.push(BeliefEvidenceNavigation.route);
      case NextMomentPromptAction.viewReview:
        context.push(WeeklyArchiveReviewNavigation.route);
    }
  }

  void _handleDailyArchiveExerciseAction(String route) {
    if (route == DailyArchiveExerciseCopy.recordRoute) {
      unawaited(_onRecordPressed(source: 'daily_archive_exercise'));
      return;
    }
    context.push(route);
  }

  void _handleTodaysOneQuestionAction(TodaysQuestionResult question) {
    if (question.primaryRoute == TodaysQuestionCopy.recordRoute) {
      setState(() => _selectedPromptLine = question.questionText);
      unawaited(_onRecordPressed(source: 'todays_one_question'));
      return;
    }
    context.push(question.primaryRoute);
  }

  Future<void> _openTodaysOneQuestionScreen() async {
    final action = await context.push<TodaysQuestionScreenAction>(
      TodaysQuestionCopy.route,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TodaysQuestionScreenAction.record:
        unawaited(_onRecordPressed(source: 'todays_one_question'));
      case TodaysQuestionScreenAction.type:
        await navigateToTypeInsteadCapture(
          context,
          prompt: _selectedPromptLine,
          onSaved: _finishSuccessfulCapture,
        );
    }
  }

  bool _compactLayout(RecordUiState ui) =>
      ui == RecordUiState.recording || ui == RecordUiState.processing;

  @override
  Widget build(BuildContext context) {
    var ui = _ui;
    var policyMic = _mic;
    var policyUserDenied = _micPermissionUserDenied;
    var error = _error;
    var localSaveTitle = _localSaveTitle;
    var syncNote = ConsumerCopyGuard.userFacingSyncNote(_syncNote);
    var stageLabel = _stageLabel;
    var entriesAfterSave = _entriesAfterSave;
    var lastCaptureAnalysisSucceeded = _lastCaptureAnalysisSucceeded;
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        ui = audit.ui;
        if (audit.entriesAfterSave != null) {
          entriesAfterSave = audit.entriesAfterSave!;
        }
        if (audit.micPhase != null) policyMic = audit.micPhase!;
        if (audit.userDeniedThisSession != null) {
          policyUserDenied = audit.userDeniedThisSession!;
        }
        error = audit.error;
        localSaveTitle = audit.localSaveTitle;
        syncNote = ConsumerCopyGuard.userFacingSyncNote(audit.syncNote);
        stageLabel = audit.stageLabel ?? _stageLabel;
        lastCaptureAnalysisSucceeded = audit.lastCaptureAnalysisSucceeded;
      }
    }

    final canRecord =
        (ui == RecordUiState.ready || ui == RecordUiState.recording) &&
        !RecordMicrophonePermissionUi.shouldHideBlockedPanelDuringRequest(ui);
    final showFraming =
        ui == RecordUiState.ready ||
        ui == RecordUiState.idle ||
        ui == RecordUiState.requestingPermission ||
        ui == RecordUiState.permissionBlocked;
    final compact = _compactLayout(ui);
    final stack = _recordStackDecision(ui);
    if (stack.showFirstRecordingHandoff && !_firstRecordCardTracked) {
      _firstRecordCardTracked = true;
      ActivationTracker.trackActivationFirstRecordCardShown();
    }
    final suppressPostResultNextCheckCompetitors =
        stack.suppressDuplicateUseTomorrowCtas;
    final auditPresentation = VisualAuditOverrides.active
        ? VisualAuditOverrides.peekRecordPresentation()
        : null;
    final justSavedFirstEntry =
        _recordReturnProJustSaved ||
        (auditPresentation?.justSavedFirst ?? false);
    final postSaveEntryCount = entriesAfterSave.isNotEmpty
        ? entriesAfterSave.length
        : _journalEntryCount;
    final suppressNoisyFirstSaveCards =
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: justSavedFirstEntry,
          entryCount: ui == RecordUiState.done && justSavedFirstEntry
              ? postSaveEntryCount
              : _journalEntryCount,
        );
    final suppressEarlyPatternClaimCards =
        FirstThreeSessionGates.suppressEarlyPatternClaimCards(
          entryCount: _journalEntryCount,
          hasGroundedRepeatMatch:
              _secondSessionComparison?.hasEnoughData == true &&
              const SecondSessionSignalEngine().hasGroundedRepeatMatch(
                _entriesAfterSave.isNotEmpty
                    ? _entriesAfterSave
                    : _journalEntries,
              ),
        );
    final suppressLatestSaveArchiveInsight = ui == RecordUiState.done &&
        ArchiveEntrySignalGuard.newestEntryIsLowSignal(entriesAfterSave);
    final secondSessionPayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? SecondSessionPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final thirdEntryBeliefPayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? ThirdEntryBeliefPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final confirmedRepeatTriggerPayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            _savedFromConfirmedRepeatTrigger
        ? EarlyFirstSignalEngine.buildTriggerCapturePayoff(
            entries: entriesAfterSave,
            savedFromTriggerPrompt: true,
          )
        : null;
    final confirmedRepeatHelpfulActionPayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            _savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildHelpfulActionPayoff(
            entries: entriesAfterSave,
            savedFromHelpfulActionPrompt: true,
          )
        : null;
    final confirmedRepeatChangeNotice = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !_savedFromConfirmedRepeatTrigger &&
            !_savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildChangeNotice(entries: entriesAfterSave)
        : null;
    final repeatReturnCheckOffer = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? RepeatReturnCheckEngine.pendingForSave(
            entriesAfterSave: entriesAfterSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final earlyEvidenceTimeline = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
              loaded: _journalEntryCountReady,
              entryCount: _journalEntryCount,
              isPostSave: _isPostSaveSurface,
            )
        ? EarlyEvidenceTimelineEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showEarlyEvidenceTimeline = earlyEvidenceTimeline != null;
    final suppressEarlyRepeatPayoffCompetitors =
        confirmedRepeatTriggerPayoff != null ||
        confirmedRepeatHelpfulActionPayoff != null ||
        confirmedRepeatChangeNotice != null;
    final earlyFirstSignalOnRecord = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !showEarlyEvidenceTimeline
        ? EarlyFirstSignalEngine.build(entries: _journalEntries)
        : null;
    final returnTomorrowCueReady = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? ReturnTomorrowCueEngine.buildReady(entries: _journalEntries)
        : null;
    final returnDayFlowCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? ReturnDayFlowEngine.build(entries: _journalEntries)
        : null;
    final showReturnDayFlow = ReturnDayFlowGates.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      flow: returnDayFlowCandidate,
      dismissedToday: ReturnDayFlowEngine.shouldHideForDismissal(),
    );
    final showReturnTomorrowCueReady = ReturnTomorrowCueGates.shouldShowReady(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      cue: returnTomorrowCueReady,
    ) &&
        !showReturnDayFlow;
    final firstWeekProgressReady = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? FirstWeekProgressEngine.buildReady(entries: _journalEntries)
        : null;
    final showFirstWeekProgressReady = FirstWeekProgressGates.shouldShowReady(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      progress: firstWeekProgressReady,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCue: showReturnTomorrowCueReady,
    );
    final showEarlyReturnReminder = ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        !showReturnDayFlow &&
        !showReturnTomorrowCueReady &&
        _earlyReturnReminderOffer &&
        !_earlyReturnReminderHidden &&
        !suppressEarlyRepeatPayoffCompetitors &&
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: _journalEntryCount,
          entries: _journalEntries,
          hasRealTimeline: showEarlyEvidenceTimeline ||
              EarlyEvidenceTimelineEngine.build(
                    entries: _journalEntries,
                    triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
                    helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
                  ) !=
                  null,
        ) &&
        (showEarlyEvidenceTimeline ||
            (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false));
    final viewingConfirmedRepeatOnRecord = showEarlyEvidenceTimeline ||
        (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false);
    final suppressConfirmedRepeatInlineFeedback =
        ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
      state: ConfirmedRepeatBetaFeedbackStore.cached,
    );
    final showConfirmedRepeatBetaFeedback = ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        _journalEntryCount >= ConfirmedRepeatBetaFeedbackGates.minEntryCount &&
        viewingConfirmedRepeatOnRecord;
    final repeatReturnChangeProof = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? RepeatReturnCheckEngine.changeProofForReady(
            entryCount: _journalEntryCount,
            viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final patternChangedCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternChangedEngine.build(
            changeProof: repeatReturnChangeProof,
            records: RepeatReturnCheckStore.cached,
            entries: _journalEntries,
          )
        : null;
    final patternChangedDismissed = patternChangedCandidate != null &&
        PatternChangedStore.isDismissed(
          entryId: patternChangedCandidate.entryId,
          type: patternChangedCandidate.type,
        );
    final confirmedRepeatThoughtMap = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ConfirmedRepeatThoughtMapEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final positivePattern = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PositivePatternEngine.build(entries: _journalEntries)
        : null;
    final helpfulActionAppearedCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? HelpfulActionAppearedEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showHelpfulActionAppearedEligible =
        HelpfulActionAppearedGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedPostSave: false,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasConfirmedRepeatFoundation:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_journalEntries),
      result: helpfulActionAppearedCandidate,
    );
    final positiveReinforcement = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface &&
            !showHelpfulActionAppearedEligible
        ? PositiveReinforcementEngine.build(
            positivePattern: positivePattern,
            entries: _journalEntries,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
          )
        : null;
    final archiveSummaryCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ArchiveSummaryEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            timeline: earlyEvidenceTimeline,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveBeliefSurfaceCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternNameEngine.applyDisplayLabels(
            ArchiveBeliefSurfaceSource().resolve(
              _journalEntries,
              confirmedRepeat: earlyFirstSignalOnRecord,
              changeProof: repeatReturnChangeProof,
              returnChecks: RepeatReturnCheckStore.cached,
              triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
              helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
              viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            ),
          )
        : ArchiveBeliefSurface.none;
    final patternNamePrompt = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PatternNameEngine.buildPrompt(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
          )
        : null;
    final showArchiveCurrentBeliefEligible = ArchiveCurrentBeliefGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasConfirmedRepeatFoundation:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_journalEntries),
      hasCurrentBeliefSurface: archiveBeliefSurfaceCandidate.isPrimaryAfterFirstProof &&
          archiveBeliefSurfaceCandidate.shouldShow,
    );
    final dailyReturnReasonCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? DailyReturnReasonEngine.build(
            entries: _journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final hasChangeOverTimeProof = repeatReturnChangeProof != null;
    final postProofArchiveProof = PaywallTimingGates.hasArchiveProofFromEntries(
      entries: _journalEntries,
      triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
      hasChangeOverTimeProof: hasChangeOverTimeProof,
    );
    final archiveSummaryVisibleForProGate = ArchiveSummaryGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasSummary: archiveSummaryCandidate != null,
    );
    final weeklyArchiveReviewVisibleForProGate = ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        weeklyReviewSurface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
          loaded: _journalEntryCountReady,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          isPostSave: _isPostSaveSurface,
          entries: _journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final hasConfirmedRepeatForProGate = viewingConfirmedRepeatOnRecord &&
        ((earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false) ||
            showEarlyEvidenceTimeline);
    final privateArchiveReportForProGate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PrivateArchiveReportEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final privateArchiveReportPreviewForProGate =
        privateArchiveReportForProGate != null &&
            PrivateArchiveReportGates.shouldShow(
              loaded: _journalEntryCountReady,
              entryCount: _journalEntryCount,
              isReady: ui == RecordUiState.ready,
              isRecording: ui == RecordUiState.recording,
              isPostSave: _isPostSaveSurface,
              viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
              report: privateArchiveReportForProGate,
            ) &&
            PrivateArchiveReportGates.showPreviewNote(
              isPro: _recordReturnProIsPro,
            );
    final patternChangedForProGate = patternChangedCandidate != null &&
        viewingConfirmedRepeatOnRecord &&
        _journalEntryCount >
            FirstThreeSessionGates.minEntriesForUsefulArchive;
    final hasReturnCheckAnsweredForProGate =
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(
              RepeatReturnCheckStore.cached,
            ) &&
            _journalEntryCount >= PaywallTimingGates.minFullArchiveHistoryEntryCount;
    final showPostProofProBridge = ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !_isPostSaveSurface &&
        _recordReturnProState != null &&
        PaywallTimingGates.showPostProofProBridge(
          entryCount: _journalEntryCount,
          resolved: _recordReturnProState!.proBridgeResolved,
          isPro: _recordReturnProIsPro,
          hasArchiveProof: postProofArchiveProof,
          viewingConfirmedRepeatOrTimeline: hasConfirmedRepeatForProGate,
          hasChangeOverTimeProof: hasChangeOverTimeProof,
          isPostSave: _isPostSaveSurface,
          hasArchiveSummary: archiveSummaryVisibleForProGate,
          hasWeeklyArchiveReview: weeklyArchiveReviewVisibleForProGate,
          hasPatternChanged: patternChangedForProGate,
          hasPrivateArchiveReportPreview: privateArchiveReportPreviewForProGate,
          hasReturnCheckAnswered: hasReturnCheckAnsweredForProGate,
        );
    final proofSurfaceLayout = ArchiveProofSurfaceLayout(
      confirmedRepeatCardVisible:
          earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false,
      timelineVisible: showEarlyEvidenceTimeline,
      changeProofVisible: repeatReturnChangeProof != null,
      proBridgeVisible: showPostProofProBridge,
      whyMattersVisible: ConfirmedRepeatWhyMattersGates.shouldShow(
        loaded: _journalEntryCountReady,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        dismissed: ConfirmedRepeatWhyMattersStore.cachedDismissed,
      ),
      thoughtMapVisible: ConfirmedRepeatThoughtMapGates.shouldShow(
        loaded: _journalEntryCountReady,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        hasThoughtMap: confirmedRepeatThoughtMap != null,
      ),
      positiveReinforcementVisible: PositiveReinforcementGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        hasPositivePattern: positiveReinforcement != null,
      ),
      positivePatternVisible: false,
      helpfulActionAppearedVisible: showHelpfulActionAppearedEligible,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        isPostSave: _isPostSaveSurface,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
        archiveSummaryVisible: ArchiveSummaryGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          hasSummary: archiveSummaryCandidate != null,
        ),
        archiveCurrentBeliefVisible: showArchiveCurrentBeliefEligible,
      );
    final showArchiveSummary = proofSurfaceLayout.effectiveArchiveSummaryVisible;
    final archiveSummary = showArchiveSummary ? archiveSummaryCandidate : null;
    final showDailyReturnReason = DailyReturnReasonGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasReason: dailyReturnReasonCandidate != null,
    );
    final dailyReturnReason =
        showDailyReturnReason ? dailyReturnReasonCandidate : null;
    final archiveWatchingCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? ArchiveWatchingEngine.build(
            entries: _journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveWatching = ArchiveWatchingGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isRecording: ui == RecordUiState.recording,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          archiveSummaryVisible: showArchiveSummary,
          hasWatching: archiveWatchingCandidate != null,
        )
        ? archiveWatchingCandidate
        : null;
    final weeklyArchiveReview = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? weeklyReviewSurface.WeeklyArchiveReviewEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final showWeeklyArchiveReview =
        weeklyReviewSurface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
      loaded: _journalEntryCountReady,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      entries: _journalEntries,
      returnChecks: RepeatReturnCheckStore.cached,
    );
    final privateArchiveReportCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? PrivateArchiveReportEngine.build(
            entries: _journalEntries,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final showPrivateArchiveReport = PrivateArchiveReportGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      report: privateArchiveReportCandidate,
    );
    final showConfirmedRepeatWhyMatters =
        proofSurfaceLayout.effectiveWhyMattersVisible;
    final showConfirmedRepeatThoughtMap =
        proofSurfaceLayout.effectiveThoughtMapVisible;
    final showPositiveReinforcement =
        proofSurfaceLayout.effectivePositiveReinforcementVisible;
    final firstWeekLoopCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? FirstWeekLoopEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final firstWeekLoopProGated = FirstWeekLoopGates.isProRequirementGated(
      valueMomentProBridgeVisible:
          _valueMomentBridge != null && _valueMomentBridge!.show,
      purchaseIntentReturnCueVisible: _purchaseIntentCue != null,
    );
    final recordProofStack = RecordProofStackPolicy.decide(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isPostSave: _isPostSaveSurface,
      isRecording: ui == RecordUiState.recording,
      archiveSummaryVisible: showArchiveSummary,
      hasEarlyFirstSignal: EarlyFirstSignalEngine.build(
            entries: _journalEntries,
          ) !=
          null,
      hasEarlyEvidenceTimeline: showEarlyEvidenceTimeline,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isReady: ui == RecordUiState.ready,
        isRecording: ui == RecordUiState.recording,
        isPostSave: _isPostSaveSurface,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
      dailyReturnReasonEligible: showDailyReturnReason,
      weeklyReviewEligible: showWeeklyArchiveReview,
      privateReportEligible: showPrivateArchiveReport,
      whyMattersEligible: showConfirmedRepeatWhyMatters,
      thoughtMapEligible: showConfirmedRepeatThoughtMap,
      positiveReinforcementEligible: showPositiveReinforcement,
      helpfulActionAppearedEligible: showHelpfulActionAppearedEligible,
      changeProofEligible: repeatReturnChangeProof != null,
      firstWeekLoopEligible: firstWeekLoopCandidate != null &&
          !firstWeekLoopProGated,
      proBridgeEligible: showPostProofProBridge,
      archiveCurrentBeliefEligible: showArchiveCurrentBeliefEligible,
    );
    final showPatternChanged = recordProofStack.showPatternChanged;
    final showArchiveCurrentBeliefOnRecord =
        recordProofStack.showArchiveCurrentBelief;
    final showEarlyEvidenceTimelineOnRecord =
        recordProofStack.showEarlyEvidenceTimeline;
    final showWeeklyArchiveReviewOnRecord =
        recordProofStack.showWeeklyArchiveWeekReview;
    final showPrivateArchiveReportOnRecord =
        recordProofStack.showPrivateArchiveReport;
    final showDailyReturnReasonOnRecord =
        recordProofStack.showDailyReturnReason;
    final showPostProofProBridgeOnRecord = recordProofStack.showProBridge;
    final firstProofPayoffSeenOnRecord =
        FirstProofPayoffEngine.build(entries: _journalEntries) != null;
    final isDegradedTranscriptOnRecord = _journalEntries.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(_journalEntries.last);
    final currentRelevanceCandidate = _journalEntryCount >= 3
        ? CurrentRelevanceEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    final patternReviewInboxActiveOnRecord =
        CurrentRelevanceEngine.patternReviewInboxHasActiveItems(
      entries: _journalEntries,
      returnChecks: RepeatReturnCheckStore.cached,
    );
    var showCurrentRelevanceOnRecordReady =
        ui == RecordUiState.ready &&
            CurrentRelevanceEngine.shouldShowOnRecordReady(
              state: currentRelevanceCandidate,
              isZeroEntryState: _journalEntryCount == 0,
              isFirstRecordingState:
                  _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              firstProofPayoffVisible: false,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final currentRelevanceQuestionActiveOnRecord =
        CurrentRelevanceEngine.isQuestionActive(
      state: currentRelevanceCandidate,
      visible: showCurrentRelevanceOnRecordReady,
    );
    final correctionMemoryCandidate = CorrectionMemoryEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    var showCorrectionMemoryOnRecordReady =
        ui == RecordUiState.ready &&
            showCurrentRelevanceOnRecordReady &&
            CorrectionMemoryEngine.shouldShowOnRecordReady(
              result: correctionMemoryCandidate,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final evidenceWeightingCandidate = _journalEntryCount >= 3
        ? EvidenceWeightingEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    var showEvidenceWeightingOnRecordReady =
        ui == RecordUiState.ready &&
            EvidenceWeightingEngine.shouldShowOnRecordReady(
              result: evidenceWeightingCandidate,
              isZeroEntryState: _journalEntryCount == 0,
              isFirstRecordingState:
                  _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              firstProofPayoffVisible: false,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final proofSpecificityCandidate = _journalEntryCount >= 3
        ? ProofSpecificityEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
          )
        : ProofSpecificityEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: false,
            source: 'record',
          );
    var showProofSpecificityOnRecordReady =
        ui == RecordUiState.ready &&
            ProofSpecificityEngine.shouldShowOnRecordReady(
              result: proofSpecificityCandidate,
              isZeroEntryState: _journalEntryCount == 0,
              isFirstRecordingState:
                  _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final presentDayRelevanceCandidate = _journalEntryCount >= 3
        ? PresentDayRelevanceEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    var showPresentDayRelevanceOnRecordReady =
        ui == RecordUiState.ready &&
            PresentDayRelevanceEngine.shouldShowOnRecordReady(
              result: presentDayRelevanceCandidate,
              isZeroEntryState: _journalEntryCount == 0,
              isFirstRecordingState:
                  _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              firstProofPayoffVisible: false,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    var showCaptureFreedomLine =
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      entryCount: _journalEntryCount,
    );
    final timelinePositioningCandidate = TimelinePositioningEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    final otherEducationCardsOnRecord =
        TimelinePositioningEngine.countOtherEducationCards(
      captureFreedomLineVisible: showCaptureFreedomLine,
      currentRelevanceVisible: showCurrentRelevanceOnRecordReady &&
          currentRelevanceCandidate != null,
      evidenceWeightingVisible: showEvidenceWeightingOnRecordReady &&
          evidenceWeightingCandidate != null,
      proofSpecificityVisible: showProofSpecificityOnRecordReady &&
          proofSpecificityCandidate.shouldShow,
      presentDayRelevanceVisible: showPresentDayRelevanceOnRecordReady &&
          presentDayRelevanceCandidate != null,
    );
    var showTimelinePositioningOnRecordReady =
        ui == RecordUiState.ready &&
            TimelinePositioningEngine.shouldShowOnRecordReady(
              result: timelinePositioningCandidate,
              entryCount: _journalEntryCount,
              otherEducationCardCount: otherEducationCardsOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              firstProofPayoffVisible: false,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final patternConfidenceEducationCount =
        PatternConfidenceEngine.countOtherEducationCards(
      captureFreedomLineVisible: showCaptureFreedomLine,
      timelinePositioningVisible: showTimelinePositioningOnRecordReady,
      currentRelevanceVisible: showCurrentRelevanceOnRecordReady &&
          currentRelevanceCandidate != null,
      correctionMemoryVisible: showCorrectionMemoryOnRecordReady &&
          correctionMemoryCandidate != null,
      evidenceWeightingVisible: showEvidenceWeightingOnRecordReady &&
          evidenceWeightingCandidate != null,
      proofSpecificityVisible: showProofSpecificityOnRecordReady &&
          proofSpecificityCandidate.shouldShow,
      presentDayRelevanceVisible: showPresentDayRelevanceOnRecordReady &&
          presentDayRelevanceCandidate != null,
    );
    final patternConfidenceExplanationCandidate =
        PatternConfidenceEngine.buildExplanation(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      returnChecks: RepeatReturnCheckStore.cached,
      changeProof: repeatReturnChangeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
    );
    var showPatternConfidenceExplanationOnRecordReady =
        ui == RecordUiState.ready &&
            PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
              result: patternConfidenceExplanationCandidate,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
              otherEducationCardCount: patternConfidenceEducationCount,
            );
    var showProEvidenceValueOnRecordReady = showPostProofProBridgeOnRecord &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: _journalEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isZeroEntryState: _journalEntryCount == 0,
            isFirstRecordingState:
                _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            currentRelevanceQuestionActive: currentRelevanceQuestionActiveOnRecord,
          ),
        );
    var showProEvidenceValuePrivateReportOnRecord =
        showPrivateArchiveReportOnRecord &&
            privateArchiveReportPreviewForProGate &&
            ProEvidenceValueEngine.shouldShowCard(
              ProEvidenceValueEngine.buildContext(
                surface: ProEvidenceValueSurface.privateReportPreview,
                entryCount: _journalEntryCount,
                isPro: _recordReturnProIsPro,
                dismissed: ProEvidenceValueDismissStore.isDismissed(),
                entries: _journalEntries,
                returnChecks: RepeatReturnCheckStore.cached,
                isDegradedTranscriptState: isDegradedTranscriptOnRecord,
                privateReportPreviewVisible: true,
              ),
            );
    final showConfirmedRepeatWhyMattersOnRecord =
        recordProofStack.showConfirmedRepeatWhyMatters;
    final showConfirmedRepeatThoughtMapOnRecord =
        recordProofStack.showConfirmedRepeatThoughtMap;
    final showPositiveReinforcementOnRecord =
        recordProofStack.showPositiveReinforcement;
    final showHelpfulActionAppearedOnRecord =
        recordProofStack.showHelpfulActionAppeared;
    final showChangeProofOnRecord = recordProofStack.showChangeProof;
    final showFirstWeekLoopOnRecord = FirstWeekLoopGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isProRequirementGated: firstWeekLoopProGated,
      policyAllows: recordProofStack.showFirstWeekLoop,
      loop: firstWeekLoopCandidate,
    );
    final firstProofPayoffCandidate = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? FirstProofPayoffEngine.build(entries: entriesAfterSave)
        : null;
    var showFirstProofPayoff = FirstProofPayoffGates.shouldShow(
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      isDegradedPostSave: entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      payoff: firstProofPayoffCandidate,
    );
    final threeDayChallengeCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? ThreeDayChallengeEngine.build(entries: _journalEntries)
        : null;
    final showThreeDayChallengeOnRecord = ThreeDayChallengeGates.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState:
          ThreeDayChallengeEngine.shouldHideForDegradedTranscript(
            _journalEntries,
          ),
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      challenge: threeDayChallengeCandidate,
    );
    final firstProofPatternConfidence = showFirstProofPayoff &&
            firstProofPayoffCandidate != null
        ? PatternConfidenceEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            hideNotEnoughYet: true,
          )
        : null;
    final firstProofTruthProofKey = showFirstProofPayoff
        ? FirstProofTruthGates.proofKeyForEntries(entriesAfterSave)
        : '';
    final showFirstProofTruth = FirstProofTruthGates.shouldShow(
      showFirstProofPayoff: showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      entries: entriesAfterSave,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof: firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofTruthAnswer = firstProofTruthProofKey.isNotEmpty
        ? FirstProofTruthStore.answerFor(firstProofTruthProofKey)
        : null;
    final showFirstProofActionLoop = FirstProofActionLoopGates.shouldShow(
      showFirstProofPayoff: showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof: firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofActionLoopContent = showFirstProofActionLoop &&
            firstProofTruthAnswer != null &&
            firstProofPayoffCandidate != null
        ? FirstProofActionLoopEngine.build(
            answer: firstProofTruthAnswer,
            entries: entriesAfterSave,
            payoff: firstProofPayoffCandidate,
          )
        : null;
    final showFirstProofMoment = showFirstProofPayoff;
    final postSaveHasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entriesAfterSave);
    final postSaveHasFirstProof = CoreValueFeedbackGates.hasFirstProof(
      entryCount: postSaveEntryCount,
      hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
    );
    final postSaveDegraded = entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final showCoreValueFeedbackOnRecordPostFirstProof =
        !showFirstProofPayoff &&
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
      showFirstProofMoment: showFirstProofMoment,
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
      isRecording: ui == RecordUiState.recording,
      isDegradedPostSave: postSaveDegraded,
      isProPaywallVisible: false,
    );
    final returnCheckPayoffCandidate = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? ReturnCheckPayoffEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Prompt = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPrompt(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Display = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPostSaveDisplay(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final showWhatChangedV2 = WhatChangedV2Engine.shouldShowOnPostSave(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave: entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      prompt: whatChangedV2Prompt,
    );
    final showWhatChangedV2Display = WhatChangedV2Engine.shouldShowPostSaveDisplay(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave: entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      display: whatChangedV2Display,
    );
    var showOpenCapturePromptChips = OpenCaptureEngine.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    var showLowFrictionReturnCard = LowFrictionReturnEngine.shouldShow(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
      entries: _journalEntries,
      dismissedForToday: LowFrictionReturnStore.isDismissedToday,
    );
    final firstMomentCaptureCandidate = FirstMomentCaptureEngine.build(
      entryCount: _journalEntryCount,
      source: 'record',
    );
    var showFirstMomentCaptureCard = FirstMomentCaptureEngine.shouldShow(
      result: firstMomentCaptureCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      isPermissionBlocked: ui == RecordUiState.permissionBlocked,
      entryCount: _journalEntryCount,
    );
    final secondMomentReturnCandidate = SecondMomentReturnEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    var showSecondMomentReturnCard = SecondMomentReturnEngine.shouldShow(
      result: secondMomentReturnCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: _journalEntryCount,
    );
    final betaTodaySummaryCandidate = BetaTodaySummaryEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    var showBetaTodaySummaryCard = BetaTodaySummaryEngine.shouldShow(
      result: betaTodaySummaryCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    final archiveTimelineSpineCandidate = _journalEntryCount >= 3
        ? ArchiveTimelineSpineEngine.build(
            entries: _journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    final whatToNoticeNextCandidate = WhatToNoticeNextEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    var showWhatToNoticeNextCard = WhatToNoticeNextEngine.shouldShow(
      result: whatToNoticeNextCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: _journalEntryCount,
      lowFrictionReturnVisible: showLowFrictionReturnCard,
      betaTodaySummaryVisible: showBetaTodaySummaryCard,
      openCapturePromptChipsVisible: showOpenCapturePromptChips,
    );
    var showArchiveTimelineSpineOnRecord =
        ui == RecordUiState.ready &&
            ArchiveTimelineSpineEngine.shouldShowOnRecordReady(
              result: archiveTimelineSpineCandidate,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              firstProofPayoffVisible:
                  showFirstProofPayoff && firstProofPayoffCandidate != null,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    final suppressLegacyEducationCardsForSpineOnRecord =
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
      result: archiveTimelineSpineCandidate,
      visible: showArchiveTimelineSpineOnRecord,
    );
    final timelineProofMomentCandidate =
        archiveTimelineSpineCandidate != null
            ? TimelineProofMomentEngine.buildFromSpine(
                spine: archiveTimelineSpineCandidate,
                entries: _journalEntries,
                source: 'record',
              )
            : null;
    var showTimelineProofMomentOnRecord =
        TimelineProofMomentEngine.shouldShowOnRecordReady(
      result: timelineProofMomentCandidate,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    final betaTesterReportCandidate = BetaTesterReportEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    var showBetaTesterReportOnRecord = BetaTesterReportEngine.shouldShow(
      result: betaTesterReportCandidate,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    final notRelevantRecoveryCandidate = NotRelevantRecoveryEngine.build(
      entries: _journalEntries,
      source: 'record',
    );
    final proofQualityResponseTimelineCandidate =
        ProofQualityResponseEngine.build(
      entries: _journalEntries,
      surface: ProofQualityResponseSurface.timelineProofMoment,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final proofQualityResponseSpineCandidate = ProofQualityResponseEngine.build(
      entries: _journalEntries,
      surface: ProofQualityResponseSurface.archiveTimelineSpine,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    var showProofQualityResponseOnRecordReady = ui == RecordUiState.ready &&
        proofQualityResponseTimelineCandidate.shouldShow &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible: showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showNotRelevantRecoveryOnRecordReady = ui == RecordUiState.ready &&
        notRelevantRecoveryCandidate.shouldShow &&
        NotRelevantRecoveryEngine.shouldRender(
          result: notRelevantRecoveryCandidate,
          parentVisible: true,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    SurfacePriorityResult? recordReadySurfacePriority;
    if (ui == RecordUiState.ready) {
      recordReadySurfacePriority = SurfacePriorityEngine.auditRecordReady(
        entryCount: _journalEntryCount,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: showFirstMomentCaptureCard,
          secondMomentReturn: showSecondMomentReturnCard,
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          timelineProofMoment: showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          archiveTimelineSpine: showArchiveTimelineSpineOnRecord &&
              archiveTimelineSpineCandidate != null,
          timelinePositioning: showTimelinePositioningOnRecordReady,
          currentRelevance: showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemory: showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          notRelevantRecovery: showNotRelevantRecoveryOnRecordReady &&
              notRelevantRecoveryCandidate.shouldShow,
          proofQualityResponse: showProofQualityResponseOnRecordReady &&
              proofQualityResponseTimelineCandidate.shouldShow,
          evidenceWeighting: showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificity: showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevance: showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
          patternConfidence:
              showPatternConfidenceExplanationOnRecordReady &&
                  patternConfidenceExplanationCandidate != null,
          betaTesterReport: showBetaTesterReportOnRecord,
          proEvidenceValue: showProEvidenceValueOnRecordReady,
          privateReportProBridge: showProEvidenceValuePrivateReportOnRecord,
          suppressLegacyEducation: suppressLegacyEducationCardsForSpineOnRecord,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordReadySurfacePriority);
      final audit = recordReadySurfacePriority;
      showFirstMomentCaptureCard = audit.isVisible(
        SurfacePriorityCardKey.firstMomentCapture,
        candidate: showFirstMomentCaptureCard,
      );
      showSecondMomentReturnCard = audit.isVisible(
        SurfacePriorityCardKey.secondMomentReturn,
        candidate: showSecondMomentReturnCard,
      );
      showLowFrictionReturnCard = audit.isVisible(
        SurfacePriorityCardKey.lowFrictionReturn,
        candidate: showLowFrictionReturnCard,
      );
      showWhatToNoticeNextCard = audit.isVisible(
        SurfacePriorityCardKey.whatToNoticeNext,
        candidate: showWhatToNoticeNextCard,
      );
      showBetaTodaySummaryCard = audit.isVisible(
        SurfacePriorityCardKey.betaTodaySummary,
        candidate: showBetaTodaySummaryCard,
      );
      showOpenCapturePromptChips = audit.isVisible(
        SurfacePriorityCardKey.openCapturePromptChips,
        candidate: showOpenCapturePromptChips,
      );
      showCaptureFreedomLine = audit.isVisible(
        SurfacePriorityCardKey.captureFreedomLine,
        candidate: showCaptureFreedomLine,
      );
      showTimelineProofMomentOnRecord = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMoment,
        candidate: showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
      );
      showArchiveTimelineSpineOnRecord = audit.isVisible(
        SurfacePriorityCardKey.archiveTimelineSpine,
        candidate: showArchiveTimelineSpineOnRecord &&
            archiveTimelineSpineCandidate != null,
      );
      showTimelinePositioningOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.timelinePositioning,
        candidate: showTimelinePositioningOnRecordReady,
      );
      showCurrentRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.currentRelevance,
        candidate: showCurrentRelevanceOnRecordReady &&
            currentRelevanceCandidate != null,
      );
      showCorrectionMemoryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.correctionMemory,
        candidate: showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
      );
      showNotRelevantRecoveryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.notRelevantRecovery,
        candidate: showNotRelevantRecoveryOnRecordReady &&
            notRelevantRecoveryCandidate.shouldShow,
      );
      showProofQualityResponseOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofQualityResponse,
        candidate: showProofQualityResponseOnRecordReady &&
            proofQualityResponseTimelineCandidate.shouldShow,
      );
      showEvidenceWeightingOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.evidenceWeighting,
        candidate: showEvidenceWeightingOnRecordReady &&
            evidenceWeightingCandidate != null,
      );
      showProofSpecificityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificity,
        candidate: showProofSpecificityOnRecordReady &&
            proofSpecificityCandidate.shouldShow,
      );
      showPresentDayRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.presentDayRelevance,
        candidate: showPresentDayRelevanceOnRecordReady &&
            presentDayRelevanceCandidate != null,
      );
      showPatternConfidenceExplanationOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.patternConfidence,
        candidate: showPatternConfidenceExplanationOnRecordReady &&
            patternConfidenceExplanationCandidate != null,
      );
      showBetaTesterReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.betaTesterReport,
        candidate: showBetaTesterReportOnRecord,
      );
      showProEvidenceValueOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValueOnRecordReady,
      );
      showProEvidenceValuePrivateReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.privateReportProBridge,
        candidate: showProEvidenceValuePrivateReportOnRecord,
      );
      final recordReadyProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordReady,
        source: 'record_ready',
        entryCount: _journalEntryCount,
        isRecording: ui == RecordUiState.recording,
        isZeroEntryState: _journalEntryCount == 0,
        isFirstRecordingState:
            _journalEntryCount <= 1 && !firstProofPayoffSeenOnRecord,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        hasFirstProof: firstProofPayoffSeenOnRecord ||
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_journalEntries),
        hasTimelineProofVisible: showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
        hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
        hasCorrectionMemoryVisible: showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: _journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
        ),
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        proSlotAvailable: true,
      );
      showProEvidenceValueOnRecordReady = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValueOnRecordReady,
        timing: recordReadyProTiming,
      );
      showProEvidenceValuePrivateReportOnRecord = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValuePrivateReportOnRecord,
        timing: recordReadyProTiming.copyWith(
          hasMonthlyPrivateReportPreviewVisible: true,
          proSlotAvailable: showProEvidenceValuePrivateReportOnRecord,
        ),
      );
    }
    if (showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null) {
      ShareableProofSeenLatch.markTimelineProofMomentSeen();
    }
    if (showBetaTesterReportOnRecord) {
      ShareableProofSeenLatch.markBetaTesterReportSeen();
    }
    final shareableNonPrivateProofResult = ShareableProofEngine.build(
      input: ShareableProofVisibilityInput(
        entryCount: _journalEntryCount,
        timelineProofMomentSeen: ShareableProofSeenLatch.timelineProofMomentSeen,
        betaTesterReportSeen: ShareableProofSeenLatch.betaTesterReportSeen,
        isRecording: ui == RecordUiState.recording,
        isDegradedTranscript: isDegradedTranscriptOnRecord,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      ),
    );
    final showShareableNonPrivateProofOnRecord =
        shareableNonPrivateProofResult.shouldShow;
    final proofSpecificityBoostCandidate = ProofSpecificityBoostEngine.build(
      entries: _journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final timelineProofParentVisible = showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null;
    var showProofSpecificityBoostOnTimelineProof = ui == RecordUiState.ready &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostCandidate,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: timelineProofParentVisible,
          timelineProofVisible: timelineProofParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showProofQualityResponseUnderTimelineProof =
        showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null &&
            ProofQualityResponseEngine.shouldRender(
              result: proofQualityResponseTimelineCandidate,
              parentVisible: true,
              timelineProofVisible: true,
              firstProofPayoffVisible: false,
              isRecording: ui == RecordUiState.recording,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    var showProofQualityResponseUnderArchiveSpine =
        showArchiveTimelineSpineOnRecord &&
            archiveTimelineSpineCandidate != null &&
            !showProofQualityResponseUnderTimelineProof &&
            ProofQualityResponseEngine.shouldRender(
              result: proofQualityResponseSpineCandidate,
              parentVisible: true,
              timelineProofVisible: false,
              firstProofPayoffVisible: false,
              isRecording: ui == RecordUiState.recording,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    var showNotRelevantRecoveryUnderTimelineProof =
        showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null &&
            NotRelevantRecoveryEngine.shouldRender(
              result: notRelevantRecoveryCandidate,
              parentVisible: true,
              isRecording: ui == RecordUiState.recording,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              isPostSaveDegradedState: false,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            );
    if (showNotRelevantRecoveryUnderTimelineProof) {
      showNotRelevantRecoveryOnRecordReady = false;
    }
    if (showProofQualityResponseUnderTimelineProof ||
        showProofQualityResponseUnderArchiveSpine) {
      showProofQualityResponseOnRecordReady = false;
      if (ProofQualityResponseEngine.coversLegacyBoost(
        result: proofQualityResponseTimelineCandidate,
        parentVisible: true,
        timelineProofVisible: showProofQualityResponseUnderTimelineProof,
        firstProofPayoffVisible: false,
        isRecording: ui == RecordUiState.recording,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      )) {
        showProofSpecificityBoostOnTimelineProof = false;
      }
      if (ProofQualityResponseEngine.coversLegacyNotRelevant(
        result: proofQualityResponseTimelineCandidate,
        parentVisible: true,
        timelineProofVisible: showProofQualityResponseUnderTimelineProof,
        firstProofPayoffVisible: false,
        isRecording: ui == RecordUiState.recording,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      ) ||
          ProofQualityResponseEngine.coversLegacyNotRelevant(
            result: proofQualityResponseSpineCandidate,
            parentVisible: true,
            timelineProofVisible: false,
            firstProofPayoffVisible: false,
            isRecording: ui == RecordUiState.recording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          )) {
        showNotRelevantRecoveryUnderTimelineProof = false;
        showNotRelevantRecoveryOnRecordReady = false;
      }
    }
    final patternReviewInboxActivePostSave =
        ProofSpecificityEngine.patternReviewInboxHasActiveItems(
      entries: entriesAfterSave,
      returnChecks: RepeatReturnCheckStore.cached,
    );
    final timelineProofMomentPostSaveCandidate =
        entriesAfterSave.length >= 3
            ? TimelineProofMomentEngine.build(
                entries: entriesAfterSave,
                beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
                source: 'record_post_save',
                compact: true,
              )
            : null;
    var showTimelineProofMomentOnFirstProofPayoff =
        TimelineProofMomentEngine.shouldShowOnFirstProofPayoffPostSave(
      result: timelineProofMomentPostSaveCandidate,
      showFirstProofPayoff: showFirstProofPayoff,
      isDegradedPostSave: entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    );
    final proofSpecificityPostSaveCandidate = entriesAfterSave.length >= 3
        ? ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          )
        : ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          );
    var showProofSpecificityOnFirstProofPayoff = ui == RecordUiState.done &&
        showFirstProofPayoff &&
        ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
          result: proofSpecificityPostSaveCandidate,
          isPostSaveDegradedState: entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    final proofSpecificityBoostPostSaveCandidate =
        ProofSpecificityBoostEngine.build(
      entries: entriesAfterSave,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record_post_save',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final proofQualityResponseFirstProofCandidate =
        ProofQualityResponseEngine.build(
      entries: entriesAfterSave,
      surface: ProofQualityResponseSurface.firstProofPayoff,
      source: 'record_post_save',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final proofQualityResponseTimelinePostSaveCandidate =
        ProofQualityResponseEngine.build(
      entries: entriesAfterSave,
      surface: ProofQualityResponseSurface.timelineProofMoment,
      source: 'record_post_save',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final firstProofPayoffParentVisible =
        showFirstProofPayoff && firstProofPayoffCandidate != null;
    var showProofSpecificityBoostOnFirstProofPayoff = ui == RecordUiState.done &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostPostSaveCandidate,
          surface: ProofSpecificityBoostSurface.firstProofPayoff,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    var showProofQualityResponseOnFirstProofPayoff = ui == RecordUiState.done &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (showProofQualityResponseOnFirstProofPayoff &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      showProofSpecificityBoostOnFirstProofPayoff = false;
    }
    final timelineProofPostSaveParentVisible =
        showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null;
    var showProofSpecificityBoostOnTimelineProofPostSave =
        ui == RecordUiState.done &&
            ProofSpecificityBoostEngine.shouldRender(
              result: proofSpecificityBoostPostSaveCandidate,
              surface: ProofSpecificityBoostSurface.timelineProofMoment,
              parentVisible: timelineProofPostSaveParentVisible,
              timelineProofVisible: timelineProofPostSaveParentVisible,
              firstProofPayoffVisible: false,
              isRecording: ui == RecordUiState.recording,
              isDegradedTranscriptState: false,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
            );
    var showProofQualityResponseOnTimelineProofPostSave =
        ui == RecordUiState.done &&
            ProofQualityResponseEngine.shouldRender(
              result: proofQualityResponseTimelinePostSaveCandidate,
              parentVisible: timelineProofPostSaveParentVisible,
              timelineProofVisible: timelineProofPostSaveParentVisible,
              firstProofPayoffVisible: false,
              isRecording: ui == RecordUiState.recording,
              isDegradedTranscriptState: false,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
            );
    if (showProofQualityResponseOnTimelineProofPostSave &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: ui == RecordUiState.recording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      showProofSpecificityBoostOnTimelineProofPostSave = false;
    }
    var showProEvidenceValuePostSave = ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
          ),
        );
    var showProLockMomentPostSave = ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProEvidenceValuePostSave &&
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: ProLockMomentDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
          ),
        );
    final monthlyPrivateReportPreviewPostSave = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? MonthlyPrivateReportEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            isPostSave: true,
          )
        : null;
    var showMonthlyPrivateReportPreviewPostSave = ui == RecordUiState.done &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProEvidenceValuePostSave &&
        !showProLockMomentPostSave &&
        monthlyPrivateReportPreviewPostSave != null &&
        MonthlyPrivateReportEngine.shouldShowCard(
          MonthlyPrivateReportEngine.buildContext(
            surface: MonthlyPrivateReportSurface.recordPostSaveAfterProof,
            entryCount: postSaveEntryCount,
            isPro: _recordReturnProIsPro,
            dismissed: MonthlyPrivateReportDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            preview: monthlyPrivateReportPreviewPostSave,
            isPostSaveDegradedState: postSaveDegraded,
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            proLockMomentVisible: showProLockMomentPostSave,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
            isPostSave: true,
          ),
        );
    const betaFeedbackRecordSurfaces = [
      BetaFeedbackIntelligenceSurface.afterProEvidenceSheet,
      BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
    ];
    final betaFeedbackIntelligenceSurfaceOnRecordReady =
        ui == RecordUiState.ready
            ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
                candidates: betaFeedbackRecordSurfaces,
                entryCount: _journalEntryCount,
                entries: _journalEntries,
                returnChecks: RepeatReturnCheckStore.cached,
                isZeroEntryState: _journalEntryCount == 0,
                isDegradedTranscriptState: isDegradedTranscriptOnRecord,
                firstProofPayoffVisible: firstProofPayoffSeenOnRecord,
              )
            : null;
    final betaFeedbackIntelligenceSurfacePostSave =
        ui == RecordUiState.done && entriesAfterSave.isNotEmpty
            ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
                candidates: betaFeedbackRecordSurfaces,
                entryCount: postSaveEntryCount,
                entries: entriesAfterSave,
                returnChecks: RepeatReturnCheckStore.cached,
                isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
                  entriesAfterSave.last,
                ),
                firstProofTruthQuestionActive: showFirstProofTruth,
                whatChangedQuestionActive: showWhatChangedV2,
                firstProofPayoffVisible:
                    showFirstProofPayoff && firstProofPayoffCandidate != null,
              )
            : null;
    final helpedTrackingPrompt = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? HelpedTrackingEngine.buildPrompt(
            entries: entriesAfterSave,
            isPostSaveDone: ui == RecordUiState.done,
            isDegradedPostSave: entriesAfterSave.isNotEmpty &&
                VoiceCaptureQuality.isDegradedVoiceCapture(
                  entriesAfterSave.last,
                ),
            showWhatChangedV2: showWhatChangedV2,
          )
        : null;
    final showHelpedTracking =
        helpedTrackingPrompt != null && !showFirstProofPayoff;
    final showReturnCheckPayoff = ReturnCheckPayoffGates.shouldShow(
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      isDegradedPostSave: entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      payoff: returnCheckPayoffCandidate,
    );
    final showArchiveSummaryOnRecord =
        recordProofStack.showArchiveSummary &&
            !showFirstProofMoment &&
            !showReturnCheckPayoff &&
            !showWhatChangedV2;
    final lowEvidenceGuidance = recordProofStack.showEarlyRepeatProgress
        ? LowEvidenceEngine.buildForRecordReady(entries: _journalEntries)
        : null;
    final quietSignalCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? QuietSignalEngine.build(entries: _journalEntries)
        : null;
    final showQuietSignalOnRecord = QuietSignalGates.shouldShowOnRecordReady(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      signal: quietSignalCandidate,
      showReturnDayFlow: showReturnDayFlow,
    );
    final showLowEvidenceGuidanceOnRecord = ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        recordProofStack.showEarlyRepeatProgress &&
        lowEvidenceGuidance != null &&
        !showReturnTomorrowCueReady &&
        !showReturnDayFlow &&
        !showQuietSignalOnRecord;
    final dailyArchiveMemoryCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? DailyArchiveMemoryEngine.build(
            entries: _journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            returnChecks: RepeatReturnCheckStore.cached,
            triggerCapturedMilestone: _earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: ui == RecordUiState.recording,
            isPostSave: _isPostSaveSurface,
          )
        : null;
    final firstProofLoopActive = showFirstProofPayoff ||
        showFirstProofTruth ||
        showFirstProofActionLoop;
    final showDailyArchiveMemory = DailyArchiveMemoryGates.shouldShow(
      loaded: _journalEntryCountReady,
      entryCount: _journalEntryCount,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      memory: dailyArchiveMemoryCandidate,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCueReady: showReturnTomorrowCueReady,
      showLowEvidenceGuidance: showLowEvidenceGuidanceOnRecord,
      showWeeklyArchiveReview: showWeeklyArchiveReviewOnRecord,
      firstProofLoopActive: firstProofLoopActive,
      showComeBackTomorrowQuietSignal: showQuietSignalOnRecord,
    );
    final betaTestScriptCardCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? BetaTestScriptEngine.buildCompactCard(entries: _journalEntries)
        : null;
    final showBetaTestScriptCard = BetaTestScriptGates.shouldShowCompactCardOnRecord(
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
      dismissed: BetaTestScriptStore.cached.dismissed,
      showReturnDayFlow: showReturnDayFlow,
      firstProofLoopActive: firstProofLoopActive,
      showWhatChangedV2Display: showWhatChangedV2Display,
    );
    final daysSinceLastEntry = CaptureRecoveryGates.daysSinceLastEntry(
      entries: _journalEntries,
    );
    final showReturnedAfterDelayRecovery = CaptureRecoveryGates.showReturnedAfterDelay(
      entryCount: _journalEntryCount,
      daysSinceLastEntry: daysSinceLastEntry,
      isReady: ui == RecordUiState.ready,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
    );
    final nextBestActionCandidate = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !_isPostSaveSurface
        ? NextBestActionEngine.build(
            entries: _journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: _earlyEvidenceHelpfulCaptured,
            privateReportForming: showPrivateArchiveReportOnRecord &&
                privateArchiveReportCandidate != null,
          )
        : null;
    final showNextBestActionOnRecord = NextBestActionGates.shouldShow(
      action: nextBestActionCandidate,
      surface: NextBestActionSurface.record,
      showEarlyRepeatProgress: recordProofStack.showEarlyRepeatProgress,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      repeatReturnCheckOfferVisible: repeatReturnCheckOffer != null,
      showPatternChangedCard:
          showPatternChanged && patternChangedCandidate != null,
      showHelpfulActionCard: showHelpfulActionAppearedOnRecord &&
          helpfulActionAppearedCandidate != null,
      showPrivateArchiveReportCard: showPrivateArchiveReportOnRecord &&
          privateArchiveReportCandidate != null,
    );
    final postSaveReturnHandoffCandidate = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? PostSaveReturnHandoffEngine.build(entries: entriesAfterSave)
        : null;
    final returnTomorrowCuePostSave = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? ReturnTomorrowCueEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final postSaveDegradedForReturnCue = entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final comeBackTomorrowV2PostSaveWatch = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? ComeBackTomorrowV2Engine.buildPostSaveWatch(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    var showComeBackTomorrowV2PostSave =
        ComeBackTomorrowV2Gates.shouldShowPostSave(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave: postSaveDegradedForReturnCue,
      watch: comeBackTomorrowV2PostSaveWatch,
      showFirstProofPayoff: showFirstProofPayoff,
      showFirstProofTruth: showFirstProofTruth,
      showFirstProofActionLoop: showFirstProofActionLoop,
      showWhatChangedV2Display: showWhatChangedV2Display,
      showHelpedTracking: showHelpedTracking,
    );
    SurfacePriorityResult? recordPostSaveSurfacePriority;
    if (ui == RecordUiState.done) {
      recordPostSaveSurfacePriority = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: postSaveEntryCount,
        source: 'record_post_save',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          firstProofPayoff:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          whatChanged: showWhatChangedV2 || showWhatChangedV2Display,
          returnPayoff: showComeBackTomorrowV2PostSave,
          timelineProofMomentPostSave:
              showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
          proofSpecificityPostSave: showProofSpecificityOnFirstProofPayoff &&
              proofSpecificityPostSaveCandidate.shouldShow,
          betaProofFeedback: showFirstProofPayoff &&
              firstProofPayoffCandidate != null,
          proEvidenceValue: showProEvidenceValuePostSave,
          proLockMoment: showProLockMomentPostSave,
          privateReportProBridge: showMonthlyPrivateReportPreviewPostSave,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordPostSaveSurfacePriority);
      final audit = recordPostSaveSurfacePriority;
      if (audit.isVisible(
        SurfacePriorityCardKey.whatChanged,
        candidate: showWhatChangedV2 || showWhatChangedV2Display,
      )) {
        showFirstProofPayoff = false;
      }
      showTimelineProofMomentOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMomentPostSave,
        candidate: showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
      );
      showProofSpecificityOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificityPostSave,
        candidate: showProofSpecificityOnFirstProofPayoff &&
            proofSpecificityPostSaveCandidate.shouldShow,
      );
      showProEvidenceValuePostSave = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValuePostSave,
      );
      showProLockMomentPostSave = audit.isVisible(
        SurfacePriorityCardKey.proLockMoment,
        candidate: showProLockMomentPostSave,
      );
      final postSaveProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordPostSave,
        source: 'record_post_save',
        entryCount: postSaveEntryCount,
        isPostSaveDegradedState: postSaveDegraded,
        hasFirstProof:
            showFirstProofPayoff && firstProofPayoffCandidate != null,
        hasTimelineProofVisible: showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
        hasFirstProofPayoffVisible: showFirstProofPayoff,
        hasMonthlyPrivateReportPreviewVisible:
            showMonthlyPrivateReportPreviewPostSave,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
        ),
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        proSlotAvailable: true,
      );
      showProEvidenceValuePostSave = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValuePostSave,
        timing: postSaveProTiming,
      );
      showProLockMomentPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProLockMomentPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable: showProLockMomentPostSave,
        ),
      );
      showMonthlyPrivateReportPreviewPostSave = ProMomentTimingEngine.applyGate(
        candidate: showMonthlyPrivateReportPreviewPostSave,
        timing: postSaveProTiming.copyWith(
          hasMonthlyPrivateReportPreviewVisible: true,
          proSlotAvailable: showMonthlyPrivateReportPreviewPostSave,
        ),
      );
    }
    final showReturnTomorrowCuePostSave = !showFirstProofPayoff &&
        !showComeBackTomorrowV2PostSave &&
        ReturnTomorrowCueGates.shouldShowPostSave(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave: postSaveDegradedForReturnCue,
      cue: returnTomorrowCuePostSave,
    );
    final firstWeekProgressPostSave = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? FirstWeekProgressEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final showFirstWeekProgressPostSave = FirstWeekProgressGates.shouldShowPostSave(
      isPostSaveDone: ui == RecordUiState.done,
      isDegradedPostSave: postSaveDegradedForReturnCue,
      progress: firstWeekProgressPostSave,
      showReturnTomorrowCue: showReturnTomorrowCuePostSave,
    );
    final showPostSaveReturnHandoff = PostSaveReturnHandoffGates.shouldShow(
      isPostSaveDone: ui == RecordUiState.done,
      entryCount: postSaveEntryCount,
      isDegradedPostSave: postSaveDegradedForReturnCue,
      handoff: postSaveReturnHandoffCandidate,
    ) &&
        !showReturnTomorrowCuePostSave &&
        !showComeBackTomorrowV2PostSave;
    final beliefUpdatePayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? BeliefUpdatePayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final journalShareProof = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? const ShareableArchiveProofEngine().buildFromJournal(
            entries: entriesAfterSave,
          )
        : null;
    final shareableProof = journalShareProof?.hasProof == true
        ? journalShareProof
        : _shareableProof;
    final returnLoopPayoff = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight &&
            thirdEntryBeliefPayoff == null &&
            beliefUpdatePayoff == null
        ? DayTwoReturnLoopPayoffEngine.build(
            entries: entriesAfterSave,
            reminderAvailable:
                _offerDayTwoReminder && !_recordReturnCueVisible,
          )
        : null;
    final postSaveDailyMirror = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? const DailyMirrorEngine().build(entriesAfterSave)
        : null;
    final postSaveArchiveHierarchy = ui == RecordUiState.done &&
            entriesAfterSave.isNotEmpty
        ? PostSaveArchiveHierarchy.resolve(
            entries: entriesAfterSave,
            suppressLatestSaveArchiveInsight: suppressLatestSaveArchiveInsight,
            beliefUpdatePayoff: beliefUpdatePayoff,
            mirror: postSaveDailyMirror,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final returningUserToday = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? ReturningUserTodayEngine.build(entries: _journalEntries)
        : null;
    final nextMomentPrompt = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? NextMomentPromptEngine.build(entries: _journalEntries)
        : null;
    final dailyArchiveExercise = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !ScreenshotMode.enabled
        ? const DailyArchiveExerciseEngine().buildFromJournal(
            entries: _journalEntries,
            hasWatchTheme: _hasWatchTheme,
            betaFeedbackCaptured: _betaFeedbackCaptured,
          )
        : null;
    final todaysOneQuestion = ui == RecordUiState.ready &&
            _journalEntryCountReady &&
            !ScreenshotMode.enabled
        ? const TodaysQuestionEngine().buildFromJournal(
            entries: _journalEntries,
            hasWatchTheme: _hasWatchTheme,
            betaFeedbackCaptured: _betaFeedbackCaptured,
            weeklyReviewAvailable: WeeklyArchiveReviewEngine.build(
              entries: _journalEntries,
            ).hasEnoughEvidence,
          )
        : null;
    final recordHomeSurface = ui == RecordUiState.ready &&
            _journalEntryCountReady
        ? RecordHomeSurfacePolicy.resolve(
            isReady: true,
            loaded: _journalEntryCountReady,
            entryCount: _journalEntryCount,
            screenshotMode: ScreenshotMode.enabled,
            dailyArchiveExercise: dailyArchiveExercise,
            returningUserToday: returningUserToday,
            todaysOneQuestion: todaysOneQuestion,
            hasStartHereSuggestion: _dailyReturnSuggestions.hasSuggestions,
          )
        : const RecordHomeSurfacePolicy();
    final showArchiveProgressCards = ui == RecordUiState.ready
        ? recordHomeSurface.showArchiveProgressCards && !showEarlyEvidenceTimeline
        : _canShowArchiveProgressCards;

    _logRecordEmptyGate('build');
    _maybeLogRecordCtaPolicy(
      _recordCtaPolicy(
        ui,
        micPhase: policyMic,
        userDeniedThisSession: policyUserDenied,
      ),
    );

    final firstUseSimplifiedRecord = ui == RecordUiState.ready &&
        RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
        );
    final readyCapturePolicy = _recordCtaPolicy(
      ui,
      micPhase: policyMic,
      userDeniedThisSession: policyUserDenied,
    );
    final showTesterMission = TesterMissionGates.shouldShow(
      dismissed: TesterMissionStore.isDismissed,
      ui: ui,
      entryCountLoaded: _journalEntryCountReady,
      isRecording: ui == RecordUiState.recording,
      isPostSave: _isPostSaveSurface,
    );
    final testerMissionCompact = showTesterMission &&
        TesterMissionGates.useCompactPresentation(
          entryCount: _journalEntryCount,
          firstUseSimplifiedRecord: firstUseSimplifiedRecord,
        );
    final showTesterMissionFull = showTesterMission && !testerMissionCompact;
    final testerMission = showTesterMission
        ? TesterMissionEngine.build(
            entryCount: _journalEntryCount,
            entries: _journalEntries,
            compactAtEntryZero: firstUseSimplifiedRecord,
            feedbackAnswered: CoreValueFeedbackStore.cached.answered,
          )
        : null;
    final showThoughtMapRecordCta = showConfirmedRepeatThoughtMapOnRecord &&
        confirmedRepeatThoughtMap?.firstMissingSection != null &&
        ConfirmedRepeatThoughtMapGates.showRecordMissingPieceCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showPositiveReinforcementRecordCta = showPositiveReinforcementOnRecord &&
        positiveReinforcement != null &&
        PositiveReinforcementGates.showRecordAgainCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
          isCompletion: positiveReinforcement.isCompletion,
        );
    final showPatternChangedRecordCta = showPatternChanged &&
        patternChangedCandidate != null &&
        PatternChangedGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showArchiveSummaryRecordCta = showArchiveSummaryOnRecord &&
        ArchiveSummaryGates.showRecordNextCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showDailyReturnReasonRecordCta = showDailyReturnReasonOnRecord &&
        DailyReturnReasonGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showFirstWeekLoopRecordCta = showFirstWeekLoopOnRecord &&
        firstWeekLoopCandidate != null &&
        FirstWeekLoopGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: _shouldHideCardRecordButtons(ui),
          promoteMicCaptureActions:
              _shouldPromoteMicCaptureActions(readyCapturePolicy),
        );

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showFirstSessionOnboarding = showFraming &&
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        FirstSessionOnboardingStore.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isPostSave: _isPostSaveSurface,
        );
    final showFirstUseWordingHelper = ui == RecordUiState.ready &&
        FirstUseWordingGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: true,
          isPostSave: _isPostSaveSurface,
          isRecordCluttered: _isPostSaveSurface,
        );
    final showCloseButton = RecordScreenCloseButton.shouldShow(context);
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              key: const Key('record_screen_scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                (compact ? 12 : 16) + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kDebugMode)
                      SizedBox(
                        key: ValueKey(
                          'record_empty_gate_${_journalEntryCount}_'
                          '$_journalEntryCountLoaded',
                        ),
                        width: 0,
                        height: 0,
                      ),
                    if (showFirstSessionOnboarding) ...[
                      FirstSessionOnboardingCard(
                        onStartMoment: () =>
                            unawaited(_onRecordPressed(source: 'main')),
                        onExploreFirst: () => unawaited(_dismissFirstSessionOnboarding()),
                      ),
                      const SizedBox(height: 16),
                    ] else if (showFraming &&
                        ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        _journalEntryCount == 0) ...[
                      const RecordTopArchivePromiseHero(),
                      const SizedBox(height: 16),
                    ],
                    if (showTesterMissionFull && testerMission != null) ...[
                      TesterMissionCard(
                        mission: testerMission,
                        onDismissed: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (recordHomeSurface.showDailyMapPrompt &&
                        dailyArchiveExercise != null) ...[
                      DailyArchiveExerciseRecordCard(
                        exercise: dailyArchiveExercise,
                        onPrimary: () => _handleDailyArchiveExerciseAction(
                          dailyArchiveExercise.primaryRoute,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        _journalEntryCount == 0 &&
                        _showFirstRunPrivacyReassurance &&
                        !firstUseSimplifiedRecord) ...[
                      const RecordFirstRunPrivacyReassurance(),
                      const SizedBox(height: 12),
                    ],
                    if (showFraming && stack.showFramingTitle) ...[
                      Text(
                        RecordScreenFramingCopy.title,
                        style: ArchiveMobileTypography.recordPageTitle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        RecordScreenFramingCopy.guidance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VoiceMemoryColors.textSecondary,
                          fontSize: ArchiveMobileTypography.responsiveBody(
                            context,
                          ).fontSize,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (recordHomeSurface.showReturningUserToday &&
                        returningUserToday != null) ...[
                      ReturningUserTodayCard(
                        model: returningUserToday,
                        onPrimary: () => _handleReturningUserTodayAction(
                          returningUserToday.primaryAction,
                        ),
                        onSecondary: () => _handleReturningUserTodayAction(
                          returningUserToday.secondaryAction,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (recordHomeSurface.showNextMomentPrompt &&
                        nextMomentPrompt != null) ...[
                      NextMomentPromptCard(
                        prompt: nextMomentPrompt,
                        onPrimary: () => _handleNextMomentPromptAction(
                          nextMomentPrompt.primaryAction,
                        ),
                        onSecondary: nextMomentPrompt.secondaryCta != null
                            ? () => _handleNextMomentPromptAction(
                                  nextMomentPrompt.secondaryAction,
                                )
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (recordHomeSurface.showTodaysOneQuestion &&
                        todaysOneQuestion != null) ...[
                      TodaysOneQuestionCard(
                        question: todaysOneQuestion,
                        onPrimary: () =>
                            _handleTodaysOneQuestionAction(todaysOneQuestion),
                        onViewFull: _openTodaysOneQuestionScreen,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (firstUseSimplifiedRecord) ...[
                      if (testerMissionCompact && testerMission != null) ...[
                        TesterMissionCard(
                          mission: testerMission,
                          onDismissed: () => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                      ],
                      RecordFirstUseCaptureSection(
                        onRecord: () =>
                            unawaited(_onRecordPressed(source: 'main')),
                        recordButtonLabel: readyCapturePolicy.primaryLabel,
                        typeCapturePrompt: _selectedPromptLine,
                        onTextThoughtSaved: _finishSuccessfulCapture,
                        onLogPressureMoment: () =>
                            context.push('/pressure-check-in'),
                        showArchiveJourneyExplainer:
                            ArchiveJourneyExplainerGates.showCompactOnRecord(
                          loaded: _journalEntryCountReady,
                          entryCount: _journalEntryCount,
                          isPostSave: _isPostSaveSurface,
                          entries: _journalEntries,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showFirstUseWordingHelper) ...[
                      FirstUseWordingHelperCard(
                        onUseOpening: (prompt) =>
                            unawaited(_openFirstUseWordingOpening(prompt)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready && !firstUseSimplifiedRecord) ...[
                      Builder(
                        builder: (context) {
                          final readyPolicy = readyCapturePolicy;
                          if (!_shouldPromoteMicCaptureActions(readyPolicy)) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCaptureEntryActions(
                                context: context,
                                selectedPrompt: _selectedPromptLine,
                                policy: readyPolicy,
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    ],
                    if (ui == RecordUiState.ready &&
                        RecordCaptureModeEngine.shouldShow(
                          loaded: _journalEntryCountReady,
                          isReady: true,
                          isPostSave: _isPostSaveSurface,
                        )) ...[
                      RecordCaptureModesCard(
                        onModeTap: (mode) =>
                            unawaited(_openCaptureMode(mode)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (recordReadySurfacePriority != null) ...[
                      SurfacePriorityDebugBadge(
                        result: recordReadySurfacePriority,
                      ),
                    ],
                    if (showSecondMomentReturnCard) ...[
                      SecondMomentReturnCard(
                        result: secondMomentReturnCandidate,
                        onNoticedSomething: () {
                          setState(() {});
                        },
                        onPromptSelected: (prompt) {
                          setState(() => _selectedPromptLine = prompt);
                        },
                        onSaveOneSentence: () => unawaited(
                          navigateToTypeInsteadCapture(
                            context,
                            prompt: _selectedPromptLine,
                            onSaved: _finishSuccessfulCapture,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showFirstMomentCaptureCard) ...[
                      FirstMomentCaptureCard(
                        result: firstMomentCaptureCandidate,
                        onSaveOneSentence: () => unawaited(
                          navigateToTypeInsteadCapture(
                            context,
                            prompt: _selectedPromptLine,
                            onSaved: _finishSuccessfulCapture,
                          ),
                        ),
                        onRecordInstead: () => unawaited(
                          _onRecordPressed(source: 'first_moment_capture'),
                        ),
                        onExampleSelected: (prompt) {
                          setState(() => _selectedPromptLine = prompt);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showOpenCapturePromptChips) ...[
                      OpenCapturePromptChips(
                        source: 'record',
                        entryCount: _journalEntryCount,
                        onChipTap: (chip) {
                          setState(
                            () => _selectedPromptLine = chip.promptStarter,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showLowFrictionReturnCard) ...[
                      LowFrictionReturnCard(
                        source: 'record',
                        entryCount: _journalEntryCount,
                        onSaveOneSentence: () => unawaited(
                          navigateToTypeInsteadCapture(
                            context,
                            prompt: _selectedPromptLine,
                            onSaved: _finishSuccessfulCapture,
                          ),
                        ),
                        onPromptSelected: (prompt) {
                          setState(() => _selectedPromptLine = prompt);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showBetaTodaySummaryCard) ...[
                      BetaTodaySummaryCard(
                        result: betaTodaySummaryCandidate,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showWhatToNoticeNextCard) ...[
                      WhatToNoticeNextCard(
                        result: whatToNoticeNextCandidate,
                        onPromptSelected: (prompt) {
                          setState(() => _selectedPromptLine = prompt);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showCaptureFreedomLine) ...[
                      CaptureFreedomLine(
                        source: 'record',
                        entryCount: _journalEntryCount,
                        compact: _journalEntryCount > 0,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showTimelinePositioningOnRecordReady) ...[
                      TimelinePositioningCard(
                        result: timelinePositioningCandidate,
                        source: 'record',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showThreeDayChallengeOnRecord &&
                        threeDayChallengeCandidate != null) ...[
                      ThreeDayChallengeCard(
                        challenge: threeDayChallengeCandidate,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready &&
                        showNextBestActionOnRecord &&
                        nextBestActionCandidate != null) ...[
                      NextBestActionLine(
                        action: nextBestActionCandidate,
                        surface: NextBestActionSurface.record,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (ui == RecordUiState.ready &&
                        recordHomeSurface.showStartHereTodayPrompt &&
                        _dailyReturnSuggestions.hasSuggestions) ...[
                      DailyReturnSuggestionsCard(
                        startHereOnly: true,
                        suggestionSet: _dailyReturnSuggestions,
                        selectedPrompt: _selectedPromptLine,
                        onSuggestionTap: _onDailySuggestionTapped,
                        onSelectPrompt: (p) {
                          ActivationTracker.trackActivationStarterPromptSelected();
                          setState(() => _selectedPromptLine = p);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showReturnedAfterDelayRecovery) ...[
                      const CaptureRecoveryHintStrip.returnedAfterDelay(),
                      const SizedBox(height: 12),
                    ],
                    if (showReturnDayFlow && returnDayFlowCandidate != null) ...[
                      ReturnDayFlowCard(
                        flow: returnDayFlowCandidate,
                        entryCount: _journalEntryCount,
                        onCameBack: () => setState(
                          () => _selectedPromptLine =
                              ComeBackTomorrowV2Copy.cameBackRecordPrompt,
                        ),
                        onDifferent: () => setState(
                          () => _selectedPromptLine =
                              ComeBackTomorrowV2Copy.differentRecordPrompt,
                        ),
                        onAnswered: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showQuietSignalOnRecord && quietSignalCandidate != null) ...[
                      QuietSignalRecordCard(
                        signal: quietSignalCandidate,
                        entryCount: _journalEntryCount,
                        onKeepWatching: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showReturnTomorrowCueReady &&
                        returnTomorrowCueReady != null) ...[
                      ReturnTomorrowCueCard(
                        cue: returnTomorrowCueReady,
                        entryCount: _journalEntryCount,
                        surface: 'record_ready',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showFirstWeekProgressReady &&
                        firstWeekProgressReady != null) ...[
                      FirstWeekProgressLine(
                        progress: firstWeekProgressReady,
                        entryCount: _journalEntryCount,
                        surface: 'record_ready',
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showLowEvidenceGuidanceOnRecord &&
                        lowEvidenceGuidance != null) ...[
                      LowEvidenceGuidanceCard(guidance: lowEvidenceGuidance),
                      const SizedBox(height: 12),
                    ],
                    if (showDailyArchiveMemory &&
                        dailyArchiveMemoryCandidate != null) ...[
                      DailyArchiveMemoryCard(
                        memory: dailyArchiveMemoryCandidate,
                        entryCount: _journalEntryCount,
                        source: 'record',
                        onRecord: () =>
                            unawaited(_onRecordPressed(source: 'daily_archive_memory')),
                        onViewPatternDetails:
                            dailyArchiveMemoryCandidate.canShowPatternDetail
                            ? _openPatternDetailFromRecord
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        recordProofStack.showEarlyFirstSignalCard &&
                        !showEarlyEvidenceTimelineOnRecord) ...[
                      if (EarlyFirstSignalEngine.build(
                            entries: _journalEntries,
                          )
                          case final signal?) ...[
                        EarlyFirstSignalCard(
                          signal: signal,
                          showPrimaryCta: !_shouldHideCardRecordButtons(ui) &&
                              FirstThreeSessionGates
                                  .showEarlyFirstSignalCardPrimaryCta(
                                signal.kind,
                              ),
                          showInsightFeedback:
                              !suppressConfirmedRepeatInlineFeedback,
                          analyticsSurface: 'record',
                          entryCount: _journalEntryCount,
                          entriesForWhy: _journalEntries,
                          onPrimary: () =>
                              unawaited(_onRecordPressed(source: 'main')),
                          onViewEvidence: signal.showsConfirmedRepeat
                              ? () => context.push(
                                    BeliefEvidenceNavigation.route,
                                  )
                              : null,
                          onReturnPrompt: signal.returnPrompt != null
                              ? () {
                                  ConfirmedRepeatTriggerCapture.armForNextSave();
                                  setState(
                                    () => _selectedPromptLine =
                                        signal.returnPrompt!.guidedRecordPrompt,
                                  );
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (showPatternChanged && patternChangedCandidate != null) ...[
                      PatternChangedCard(
                        result: patternChangedCandidate,
                        entryCount: _journalEntryCount,
                        surface: 'record',
                        showRecordCta: showPatternChangedRecordCta,
                        onRecord: () => _handlePatternChangedRecord(
                          patternChangedCandidate,
                        ),
                        onDismissed: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showArchiveCurrentBeliefOnRecord &&
                        ui == RecordUiState.ready &&
                        archiveBeliefSurfaceCandidate.shouldShow) ...[
                      ArchiveBeliefSurfaceCard(
                        surface: archiveBeliefSurfaceCandidate,
                        onRecordNext: () => unawaited(
                          _onRecordPressed(source: 'archive_current_belief'),
                        ),
                      ),
                      if (patternNamePrompt != null) ...[
                        const SizedBox(height: 12),
                        PatternNameConfirmationCard(
                          prompt: patternNamePrompt,
                          source: 'record',
                          entryCount: _journalEntryCount,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (showTimelineProofMomentOnRecord &&
                        timelineProofMomentCandidate != null) ...[
                      TimelineProofMomentCard(
                        result: timelineProofMomentCandidate,
                        source: 'record',
                      ),
                      BetaProofFeedbackRow(
                        surface: BetaProofFeedbackSurface.timelineProofMoment,
                        source: 'record',
                        entryCount: _journalEntryCount,
                        hasConfirmedRepeat:
                            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          _journalEntries,
                        ),
                        parentVisible: true,
                        isRecording: ui == RecordUiState.recording,
                        isPostSaveDegraded: false,
                        whatChangedQuestionActive: showWhatChangedV2,
                        patternReviewInboxHasActiveItems:
                            patternReviewInboxActiveOnRecord,
                        onNotRelevantAnswered: () =>
                            NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                          entries: _journalEntries,
                          source: 'record',
                        ),
                        onChanged: () => setState(() {}),
                      ),
                      if (showProofQualityResponseUnderTimelineProof) ...[
                        const SizedBox(height: 12),
                        ProofQualityResponseCard(
                          result: proofQualityResponseTimelineCandidate,
                          source: 'record',
                          onChanged: () => setState(() {}),
                        ),
                      ] else ...[
                        if (showNotRelevantRecoveryUnderTimelineProof) ...[
                          const SizedBox(height: 12),
                          NotRelevantRecoveryCard(
                            result: notRelevantRecoveryCandidate,
                            source: 'record',
                            onChanged: () => setState(() {}),
                          ),
                        ],
                        if (showProofSpecificityBoostOnTimelineProof) ...[
                          const SizedBox(height: 12),
                          ProofSpecificityBoostCard(
                            result: proofSpecificityBoostCandidate,
                            surface:
                                ProofSpecificityBoostSurface.timelineProofMoment,
                            source: 'record',
                            hasConfirmedRepeat:
                                EarlyFirstSignalEngine
                                    .hasConfirmedRepeatFoundation(
                              _journalEntries,
                            ),
                            proofKey:
                                CurrentRelevanceStore.proofKeyFor(_journalEntries),
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (showArchiveTimelineSpineOnRecord &&
                        archiveTimelineSpineCandidate != null) ...[
                      ArchiveTimelineSpineCard(
                        result: archiveTimelineSpineCandidate,
                        source: 'record',
                      ),
                      BetaProofFeedbackRow(
                        surface: BetaProofFeedbackSurface.archiveTimelineSpine,
                        source: 'record',
                        entryCount: _journalEntryCount,
                        hasConfirmedRepeat:
                            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          _journalEntries,
                        ),
                        parentVisible: true,
                        isRecording: ui == RecordUiState.recording,
                        isPostSaveDegraded: false,
                        whatChangedQuestionActive: showWhatChangedV2,
                        patternReviewInboxHasActiveItems:
                            patternReviewInboxActiveOnRecord,
                        onNotRelevantAnswered: () =>
                            NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
                          entries: _journalEntries,
                          source: 'record',
                        ),
                        onChanged: () => setState(() {}),
                      ),
                      if (showProofQualityResponseUnderArchiveSpine) ...[
                        const SizedBox(height: 12),
                        ProofQualityResponseCard(
                          result: proofQualityResponseSpineCandidate,
                          source: 'record',
                          onChanged: () => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (showBetaTesterReportOnRecord) ...[
                      BetaTesterReportCard(
                        result: betaTesterReportCandidate,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showShareableNonPrivateProofOnRecord) ...[
                      ShareableProofCard(
                        result: shareableNonPrivateProofResult,
                        source: 'record',
                        surface: 'record_ready',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showCurrentRelevanceOnRecordReady &&
                        currentRelevanceCandidate != null) ...[
                      CurrentRelevanceCard(
                        state: currentRelevanceCandidate,
                        source: 'record',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showCorrectionMemoryOnRecordReady &&
                        correctionMemoryCandidate != null) ...[
                      CorrectionMemoryCard(
                        result: correctionMemoryCandidate,
                        source: 'record',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showProofQualityResponseOnRecordReady &&
                        !showProofQualityResponseUnderTimelineProof &&
                        !showProofQualityResponseUnderArchiveSpine &&
                        proofQualityResponseTimelineCandidate.shouldShow) ...[
                      ProofQualityResponseCard(
                        result: proofQualityResponseTimelineCandidate,
                        source: 'record',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ] else if (showNotRelevantRecoveryOnRecordReady &&
                        !showNotRelevantRecoveryUnderTimelineProof &&
                        notRelevantRecoveryCandidate.shouldShow) ...[
                      NotRelevantRecoveryCard(
                        result: notRelevantRecoveryCandidate,
                        source: 'record',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showEvidenceWeightingOnRecordReady &&
                        evidenceWeightingCandidate != null) ...[
                      EvidenceWeightingCard(
                        result: evidenceWeightingCandidate,
                        source: 'record',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showProofSpecificityOnRecordReady &&
                        proofSpecificityCandidate.shouldShow) ...[
                      ProofSpecificityCard(
                        result: proofSpecificityCandidate,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showPresentDayRelevanceOnRecordReady &&
                        presentDayRelevanceCandidate != null) ...[
                      PresentDayRelevanceCard(
                        result: presentDayRelevanceCandidate,
                        source: 'record',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!suppressLegacyEducationCardsForSpineOnRecord &&
                        showPatternConfidenceExplanationOnRecordReady &&
                        patternConfidenceExplanationCandidate != null) ...[
                      PatternConfidenceCard(
                        result: patternConfidenceExplanationCandidate,
                        source: 'record',
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showArchiveSummaryOnRecord &&
                        ui == RecordUiState.ready &&
                        archiveSummary != null) ...[
                      ArchiveSummaryCard(
                        summary: archiveSummary,
                        showRecordNextCta: showArchiveSummaryRecordCta,
                        watching: archiveWatching,
                        onRecordNext: () => _handleArchiveSummaryRecordNext(
                          archiveSummary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showDailyReturnReasonOnRecord &&
                        dailyReturnReason != null) ...[
                      DailyReturnReasonCard(
                        reason: dailyReturnReason,
                        showRecordCta: showDailyReturnReasonRecordCta,
                        onRecord: () => _handleDailyReturnReason(
                          dailyReturnReason,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showEarlyEvidenceTimelineOnRecord) ...[
                      EarlyEvidenceTimelineCard(
                        timeline: earlyEvidenceTimeline!,
                        compact: true,
                        nearbyConfirmedRepeat: proofSurfaceLayout.timelineNearby,
                        suppressEvidencePhrases:
                            proofSurfaceLayout.suppressTimelineEvidencePhrases,
                        analyticsSurface: 'record',
                        entryCount: _journalEntryCount,
                        entriesForWhy: _journalEntries,
                        onRecordWhatHelped:
                            earlyEvidenceTimeline.showsSofterReturn &&
                                !earlyEvidenceTimeline.showsHelpfulAction
                            ? () {
                                ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                                setState(
                                  () => _selectedPromptLine =
                                      EarlyFirstSignalCopy
                                          .recordWhatHelpedGuidedPrompt,
                                );
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showWeeklyArchiveReviewOnRecord &&
                        weeklyArchiveReview != null) ...[
                      weeklyReviewSurface.WeeklyArchiveReviewCard(
                        review: weeklyArchiveReview,
                        onViewReview: () => _openWeeklyArchiveReview(
                          weeklyArchiveReview,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showPrivateArchiveReportOnRecord &&
                        privateArchiveReportCandidate != null) ...[
                      PrivateArchiveReportCard(
                        report: privateArchiveReportCandidate,
                        entryCount: _journalEntryCount,
                        surface: 'record',
                        isPro: _recordReturnProIsPro,
                        onSeePro: _recordReturnProIsPro
                            ? null
                            : () => unawaited(
                                  _resolveRecordReturnProBridge(seePro: true),
                                ),
                      ),
                      if (BetaProofFeedbackEngine.shouldShowOnPrivateArchiveReportPreview(
                        privateArchiveReportVisible: true,
                        isPro: _recordReturnProIsPro,
                        entryCount: _journalEntryCount,
                        hasConfirmedRepeat:
                            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          _journalEntries,
                        ),
                        isRecording: ui == RecordUiState.recording,
                        isPostSaveDegraded: false,
                        whatChangedQuestionActive: showWhatChangedV2,
                        patternReviewInboxHasActiveItems:
                            patternReviewInboxActiveOnRecord,
                      ))
                        BetaProofFeedbackRow(
                          surface: BetaProofFeedbackSurface
                              .privateArchiveReportPreview,
                          source: 'record',
                          entryCount: _journalEntryCount,
                          hasConfirmedRepeat:
                              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                            _journalEntries,
                          ),
                          parentVisible: true,
                          isRecording: ui == RecordUiState.recording,
                          isPostSaveDegraded: false,
                          whatChangedQuestionActive: showWhatChangedV2,
                          patternReviewInboxHasActiveItems:
                              patternReviewInboxActiveOnRecord,
                          onChanged: () => setState(() {}),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (showProEvidenceValuePrivateReportOnRecord) ...[
                      ProEvidenceValueCard(
                        surface: ProEvidenceValueSurface.privateReportPreview,
                        entryCount: _journalEntryCount,
                        compact: true,
                        onSeePro: () => _openProEvidenceValueSubscription(
                          analyticsSource: 'record_private_report_pro_evidence_value',
                        ),
                        onDismiss: () =>
                            unawaited(_dismissProEvidenceValueBridge()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showConfirmedRepeatWhyMattersOnRecord) ...[
                      ConfirmedRepeatWhyMattersCard(
                        onDismissed: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showConfirmedRepeatThoughtMapOnRecord &&
                        confirmedRepeatThoughtMap != null) ...[
                      ConfirmedRepeatThoughtMapCard(
                        result: confirmedRepeatThoughtMap,
                        showRecordMissingPieceCta: showThoughtMapRecordCta,
                        onRecordMissingPiece: () => _handleThoughtMapMissingPiece(
                          confirmedRepeatThoughtMap,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showHelpfulActionAppearedOnRecord &&
                        helpfulActionAppearedCandidate != null) ...[
                      HelpfulActionAppearedCard(
                        result: helpfulActionAppearedCandidate,
                        entryCount: _journalEntryCount,
                        source: 'record',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showPositiveReinforcementOnRecord &&
                        positiveReinforcement != null) ...[
                      PositiveReinforcementCard(
                        reinforcement: positiveReinforcement,
                        showRecordAgainCta: showPositiveReinforcementRecordCta,
                        onRecordAgain: () => _handlePositiveReinforcementRecordAgain(
                          positiveReinforcement,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showChangeProofOnRecord &&
                        repeatReturnChangeProof != null) ...[
                      RepeatReturnCheckChangeProofCard(
                        proof: repeatReturnChangeProof,
                        entryCount: _journalEntryCount,
                        surface: 'record',
                        onRecordNext: () =>
                            unawaited(_onRecordPressed(source: 'repeat_return_proof')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showConfirmedRepeatBetaFeedback &&
                        !showArchiveSummaryOnRecord) ...[
                      ConfirmedRepeatBetaFeedbackCard(
                        entryCount: _journalEntryCount,
                        surface: 'record',
                        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
                        isRecording: ui == RecordUiState.recording,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showFirstWeekLoopOnRecord &&
                        firstWeekLoopCandidate != null) ...[
                      FirstWeekLoopCard(
                        loop: firstWeekLoopCandidate,
                        entryCount: _journalEntryCount,
                        showRecordCta: showFirstWeekLoopRecordCta,
                        onRecord: () =>
                            unawaited(_onRecordPressed(source: 'first_week_loop')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showBetaTestScriptCard &&
                        betaTestScriptCardCandidate != null) ...[
                      BetaTestScriptCard(
                        card: betaTestScriptCardCandidate,
                        onViewSteps: () {
                          BetaTestScriptSheet.show(
                            context,
                            entries: _journalEntries,
                            source: 'record',
                            onReset: () {
                              if (mounted) setState(() {});
                            },
                          );
                        },
                        onSendFeedback: betaTestScriptCardCandidate
                                .showSendFeedbackSecondary
                            ? () {
                                BetaFeedbackSheet.show(
                                  context,
                                  source: 'record_beta_test_script',
                                  entryCount: _journalEntryCount,
                                );
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showProEvidenceValueOnRecordReady) ...[
                      ProEvidenceValueCard(
                        surface: ProEvidenceValueSurface.recordReady,
                        entryCount: _journalEntryCount,
                        compact: proofSurfaceLayout.proBridgeCompact,
                        onSeePro: () => _openProEvidenceValueSubscription(
                          analyticsSource: 'record_pro_evidence_value',
                        ),
                        onDismiss: () =>
                            unawaited(_dismissProEvidenceValueBridge()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (betaFeedbackIntelligenceSurfaceOnRecordReady != null) ...[
                      BetaFeedbackIntelligenceCard(
                        surface: betaFeedbackIntelligenceSurfaceOnRecordReady,
                        entryCount: _journalEntryCount,
                        reachedFirstProof: firstProofPayoffSeenOnRecord,
                        compact: proofSurfaceLayout.proBridgeCompact,
                        onSubmitted: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ui == RecordUiState.ready &&
                        _journalEntryCountReady &&
                        RecordEmptyArchiveGates.showConfirmedRepeatChangeNoticeCard(
                          loaded: _journalEntryCountReady,
                          entryCount: _journalEntryCount,
                          isPostSave: _isPostSaveSurface,
                        ) &&
                        !showEarlyEvidenceTimelineOnRecord &&
                        !showArchiveSummaryOnRecord) ...[
                      if (EarlyFirstSignalEngine.buildChangeNotice(
                            entries: _journalEntries,
                          )
                          case final notice?) ...[
                        ConfirmedRepeatChangeNoticeCard(
                          notice: notice,
                          analyticsSurface: 'record',
                          entryCount: _journalEntryCount,
                          entriesForWhy: _journalEntries,
                          onRecordWhatHelped: () {
                            ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                            setState(
                              () => _selectedPromptLine =
                                  notice.guidedRecordPrompt,
                            );
                          },
                          onViewEvidence: () => context.push(
                            BeliefEvidenceNavigation.route,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (showEarlyReturnReminder) ...[
                      EarlyArchiveReturnReminderCard(
                        source: 'record',
                        onDismiss: () =>
                            setState(() => _earlyReturnReminderHidden = true),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Zero-entry intro card removed — [RecordTopArchivePromiseHero]
                    // carries the first-open promise without a second competing card.
                    if (ui == RecordUiState.ready &&
                        recordHomeSurface.showDailyMirrorCard &&
                        !(_journalEntryCountReady && _journalEntryCount == 0)) ...[
                      DailyMirrorRecordCard(
                        mirror: _dailyMirror,
                        onPrimaryCta: () => unawaited(_onRecordPressed(source: 'moment')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      if (_showFirstRunPrivacyReassurance) ...[
                        const SizedBox(height: 8),
                        const RecordFirstRunPrivacyReassurance(),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (_missedCheckInForDiagnosis != null &&
                        ui == RecordUiState.ready &&
                        _showBottomRetentionCards) ...[
                      MissedCheckInReasonPrompt(
                        checkIn: _missedCheckInForDiagnosis!,
                        onAnswered: () =>
                            setState(() => _missedCheckInForDiagnosis = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if ((_showCurrentObjectiveOnRecord &&
                            (ui == RecordUiState.ready
                                ? recordHomeSurface.showCurrentObjectiveCard
                                : stack.showCurrentObjectiveCard) &&
                            !_shouldHideCompetingRecordCtas(ui)) ||
                        (ScreenshotMode.enabled &&
                            ScreenshotMode.objective != null)) ...[
                      _currentObjectiveWidget(stack)!,
                      const SizedBox(height: 16),
                    ],
                    if ((ui == RecordUiState.ready
                            ? recordHomeSurface.showRetentionStateCard
                            : stack.showRetentionStateCard) &&
                        showArchiveProgressCards) ...[
                      _retentionCardWidget(stack)!,
                      const SizedBox(height: 16),
                    ],
                    if (stack.showDueCheckCard &&
                        _journalEntryCountReady &&
                        _journalEntryCount >= 1) ...[
                      Builder(
                        builder: (context) {
                          final guided =
                              _hookRescue?.includes(
                                HookRescueAction.guidedCheckIn,
                              ) ??
                              false;
                          return TomorrowCheckInDueCard(
                            checkIn: _dueCheckInToday!,
                            plannedAnchor: _dueRoutineAnchor,
                            guided: guided,
                            // Fast path by default; only the gated guided flow opts
                            // out so confused users still get the step-by-step card.
                            oneTapMode: !guided,
                            onRecord: () => unawaited(_onRecordPressed(source: 'moment')),
                            onSelectOption: (option) async {
                              final checkInId = _dueCheckInToday!.id;
                              final updated =
                                  await TomorrowCheckInCoordinator.selectOption(
                                    checkInId: checkInId,
                                    optionId: option.id,
                                  );
                              await ReturnDayFrictionCoordinator.markAnswerSelected(
                                checkInId,
                                option.id,
                              );
                              if (!mounted) return;
                              setState(() {
                                _dueCheckInToday = updated;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (stack.showReturnDayJourneyCard &&
                        showArchiveProgressCards &&
                        _signalJourney != null &&
                        ui == RecordUiState.ready) ...[
                      ReturnDayJourneyCard(
                        journey: _signalJourney!,
                        recordedToday: const ReturnDayJourneyEngine()
                            .evaluate(
                              journey: _signalJourney,
                              reflectionCount: _journalEntryCount,
                              now: DateTime.now(),
                              lastReflectionAt: _lastReflectionAt,
                            )
                            .recordedToday,
                        onViewChanged: () => context.push('/signal-journey'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_shouldHideCompetingRecordCtas(ui) &&
                        _activeLoop?.isCapacityYes == true &&
                        CapacityLoopGates.showRecordPrompt(
                          capacityWedgeActive: true,
                          sampleMode: ScreenshotMode.enabled,
                        ) &&
                        ui == RecordUiState.ready &&
                        _mic == RecordingPhase.ready &&
                        _postSavePattern == null) ...[
                      BeforeYouSayYesCard(
                        result: const BeforeYesPauseEngine().build(
                          BeforeYesPauseInput(
                            capacityWedgeActive: true,
                            sampleMode: ScreenshotMode.enabled,
                            realSavedMomentCount: 0,
                            capacityEvidenceCount: 0,
                            capacityLoopHasCard: false,
                            costLaterCheckinVisible: false,
                            recordedCostCount: 0,
                          ),
                        ),
                        onPauseBeforeYes: () {
                          setState(
                            () => _selectedPromptLine = BeforeYesCopy.recordPrompt,
                          );
                          unawaited(
                            _onRecordPressed(source: 'before_yes_pause'),
                          );
                        },
                        onAlreadySaidYes: () {
                          setState(
                            () => _selectedPromptLine =
                                LoopModeCopy.capacityHandoffPrompt,
                          );
                          unawaited(
                            _onRecordPressed(source: 'capacity_loop'),
                          );
                        },
                        onQuickSave: () => context.push(
                          LowEffortYesCaptureCopy.route,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LowEffortYesCaptureCard(
                        result: const LowEffortYesCaptureEngine().build(
                          const LowEffortYesCaptureInput(
                            capacityWedgeActive: true,
                            sampleMode: false,
                            screenshotMode: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final threeMoment =
                              const CapacityThreeMomentEngine().buildFromJournal(
                            entries: _journalEntries,
                            capacityLoopActive:
                                _activeLoop?.isCapacityYes ?? false,
                            capacityCohortActive: false,
                            sampleMode: false,
                          );
                          final progressLine =
                              CapacityThreeMomentEngine.recordProgressLine(
                            threeMoment,
                          );
                          if (progressLine.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              Text(
                                progressLine,
                                key: const Key(
                                  'record_screen_capacity_three_moment_progress',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: VoiceMemoryColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    ],
                    if (_showDefaultBoundaryPauseOnRecord(ui)) ...[
                      Text(
                        _defaultBoundaryPauseLabel!,
                        key: const Key('record_screen_default_boundary_pause'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: VoiceMemoryColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showFirstRecordingHandoff &&
                        _activeLoop != null) ...[
                      LoopModeFirstHandoffCard(
                        loop: _activeLoop!,
                        onStartRecording: () => _onRecordPressed(source: 'main'),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showFirstRecordingHandoff) ...[
                      FirstRecordingHandoffCard(
                        onStartRecording: () => _onRecordPressed(source: 'main'),
                        wedgePrompt: _selectedPromptLine,
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        _activeLoop != null &&
                        showArchiveProgressCards &&
                        _postSavePattern == null &&
                        !stack.showReturnDayJourneyCard) ...[
                      LoopModeProgressCard(
                        loop: _activeLoop!,
                        onRecordNext: () => unawaited(_onRecordPressed(source: 'loop')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ] else if (!_shouldHideCompetingRecordCtas(ui) &&
                        stack.showArchiveMemoryDemo) ...[
                      ArchiveMemoryDemoCard(
                        onRecord: () => unawaited(_onRecordPressed(source: 'main')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (stack.showFirstLoopStartCard &&
                        !_shouldHideCompetingRecordCtas(ui)) ...[
                      FirstLoopStartCard(
                        onRecord: () => unawaited(_onRecordPressed(source: 'loop')),
                        showRecordCta: !_shouldHideCardRecordButtons(ui),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (stack.showTrialFirstMomentCard &&
                        !_shouldHideCompetingRecordCtas(ui)) ...[
                      TrialFirstMomentCard(
                        onStartRecording: () =>
                            unawaited(_onRecordPressed(source: 'main')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
                      ui: ui,
                      micPhase: _mic,
                      userDeniedThisSession: _micPermissionUserDenied,
                    )) ...[
                      KeyedSubtree(
                        key: _permissionPanelKey,
                        child: MicrophonePermissionBlockedPanel(
                          showSimulatorHelper: _showMicPermissionSimulatorHelper,
                          onOpenSettings: _openMicSettings,
                          onTypeInstead: _typeInsteadFromPermission,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (ui == RecordUiState.recording) ...[
                      _RecordingStatusCard(
                        seconds: _seconds,
                        stageLabel: stageLabel,
                      ),
                      if (_selectedPromptLine != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _selectedPromptLine!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VoiceMemoryColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ] else ...[
                      if (ui == RecordUiState.ready &&
                          _showReadyToRecordStatus) ...[
                        Semantics(
                          label: 'Recording status',
                          child: Text(
                            stageLabel.isEmpty
                                ? _statusTextFor(ui, localSaveTitle)
                                : stageLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.processing) ...[
                        const SizedBox(height: 12),
                        PostSaveListeningCard(stageLabel: stageLabel),
                      ],
                      if (_selectedPromptLine != null &&
                          _showBottomRetentionCards &&
                          (ui == RecordUiState.ready ||
                              ui == RecordUiState.recording)) ...[
                        const SizedBox(height: 12),
                        Text(
                          ConsumerUiCopy.trySayingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: VoiceMemoryColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedPromptLine!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VoiceMemoryColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          recordHomeSurface.showNextEvidencePrompt &&
                          _nextEvidencePrompt != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ConsumerUiCopy.postSaveInsightRecordThisNext,
                                style: ArchiveMobileTypography.cardLabel(
                                  context,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _nextEvidencePrompt!,
                                style: ArchiveMobileTypography.explanationBody(
                                  context,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          stack.showActivePatternThread &&
                          _activePatternThread != null) ...[
                        const SizedBox(height: 12),
                        ActivePatternThreadPromptCard(
                          thread: _activePatternThread!,
                          onAddMoment: () => unawaited(_onRecordPressed(source: 'moment')),
                          onPause: () async {
                            await ActivePatternThreadCoordinator.pauseThread();
                            if (!mounted) return;
                            setState(() => _activePatternThread = null);
                          },
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          stack.showFirstThreeJourney &&
                          _firstThreeJourney != null &&
                          _firstThreeJourney!.showOnRecord &&
                          _showFirstThreeJourneyOnRecord) ...[
                        const SizedBox(height: 12),
                        FirstThreeJourneyCard(model: _firstThreeJourney!),
                      ],
                      if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          _postSavePattern == null &&
                          !stack.showReturnDayJourneyCard &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.isActive) ...[
                        const SizedBox(height: 12),
                        SignalJourneyCard(
                          journey: _signalJourney!,
                          activeLoop: _activeLoop,
                          compact: true,
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.showCompletion &&
                          !_journeyCompletionDismissed &&
                          _signalReview != null &&
                          _signalReview!.isShowable) ...[
                        const SizedBox(height: 12),
                        SignalReviewCard(
                          review: _signalReview!,
                          onConfirm: () async {
                            await SignalReviewCoordinator.confirm(
                              reviewId: _signalReview!.id,
                            );
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                          },
                          onCorrect: () {
                            SignalReviewNavigation.openFullReview(context);
                          },
                          onKeepWatching: () async {
                            await SignalReviewCoordinator.keepWatching(
                              reviewId: _signalReview!.id,
                            );
                            final journey =
                                await SignalJourneyCoordinator.loadActive();
                            if (journey != null) {
                              unawaited(
                                NextEvidenceReminderService.schedule(
                                  journeyId: journey.id,
                                  prompt: _signalReview!.nextEvidencePrompt,
                                ),
                              );
                            }
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                            SignalReviewNavigation.recordNextEvidence(
                              context,
                              prompt: _signalReview!.nextEvidencePrompt,
                            );
                          },
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalJourney != null &&
                          _signalJourney!.showCompletion &&
                          !_journeyCompletionDismissed) ...[
                        const SizedBox(height: 12),
                        SignalJourneyCompletionCard(
                          journey: _signalJourney!,
                          onKeepWatching: () async {
                            await SignalJourneyCoordinator.acknowledgeCompletion();
                            if (!mounted) return;
                            setState(() => _journeyCompletionDismissed = true);
                            unawaited(_loadSignalArchive());
                          },
                          onViewPattern: () => context.go('/archive-belief'),
                        ),
                      ] else if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          _postSavePattern == null &&
                          _showRetentionJourneyCards &&
                          _signalArchiveSnapshot?.hasActiveSignal == true) ...[
                        const SizedBox(height: 12),
                        ArchiveWatchingCard(
                          snapshot: _signalArchiveSnapshot!,
                          compact: true,
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          showArchiveProgressCards &&
                          stack.showPendingWatchFor &&
                          _pendingWatchForToday != null) ...[
                        const SizedBox(height: 12),
                        TodaysWatchForCard(
                          pending: _pendingWatchForToday!,
                          onRecord: () => unawaited(_onRecordPressed(source: 'moment')),
                          onSkip: () async {
                            await WatchForCoordinator.skipPendingForToday();
                            if (!mounted) return;
                            setState(() => _pendingWatchForToday = null);
                          },
                        ),
                      ],
                      if (ui == RecordUiState.ready &&
                          recordHomeSurface.showOneSmallRecordingCard &&
                          stack.showStarterPrompts &&
                          recordHomeSurface.showWorthCheckingToday) ...[
                        if (_oneSmallRecording.hasRecording) ...[
                          const SizedBox(height: 12),
                          OneSmallRecordingCard(
                            recording: _oneSmallRecording,
                            showRecordCta: !_shouldHideCardRecordButtons(ui),
                            ctaLabel:
                                _recordCtaPolicy(
                                  ui,
                                  micPhase: policyMic,
                                  userDeniedThisSession: policyUserDenied,
                                ).primaryLabel ??
                                OneSmallRecording.recordCtaLabel,
                            onRecordThis: (p) {
                              ActivationTracker.trackActivationStarterPromptSelected();
                              setState(() => _selectedPromptLine = p);
                              unawaited(
                                _onRecordPressed(source: 'one_small_recording'),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          LowEffortCheckInCard(onSelect: _saveLowEffortCheckIn),
                        ],
                        if (_dailyReturnSuggestions.hasSuggestions &&
                            recordHomeSurface.showWorthCheckingToday) ...[
                          const SizedBox(height: 12),
                          DailyReturnSuggestionsCard(
                            suggestionSet: _dailyReturnSuggestions,
                            selectedPrompt: _selectedPromptLine,
                            onSuggestionTap: _onDailySuggestionTapped,
                            onSelectPrompt: (p) {
                              ActivationTracker.trackActivationStarterPromptSelected();
                              setState(() => _selectedPromptLine = p);
                            },
                          ),
                        ],
                        if (recordHomeSurface.showTrySayingPrompts) ...[
                          const SizedBox(height: 12),
                          ConsumerRecordPromptsSection(
                            selectedPrompt: _selectedPromptLine,
                            personalPrompts: _personalReturnPrompts,
                            deemphasized: _oneSmallRecording.hasRecording,
                            onSelectPrompt: (p) {
                              ActivationTracker.trackActivationStarterPromptSelected();
                              _pendingSuggestionSource = null;
                              _pendingTappedSuggestion = null;
                              setState(() => _selectedPromptLine = p);
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Say it plainly. ArchiveMe looks for patterns, '
                            'not judgment.',
                            style: VoiceMemoryTypography.metadataStyle(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          QuickHelpButton(
                            languageCode: _languageCode,
                            patternTitle: _activePatternThread?.title,
                            onStartRecording: () => _onRecordPressed(source: 'main'),
                          ),
                        ],
                      ],
                      if (ui == RecordUiState.done &&
                          entriesAfterSave.isNotEmpty) ...[
                        if (!suppressNoisyFirstSaveCards) ...[
                          if (!VoiceCaptureQuality.isDegradedVoiceCapture(
                            entriesAfterSave.first,
                          )) ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: VoiceMemoryColors.captureSuccess,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    BeliefProductCopy.reflectionSavedTitle,
                                    style: VoiceMemoryTypography.cardTitleStyle(
                                      color: VoiceMemoryColors.captureSuccess,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            const SizedBox(height: 16),
                          ],
                          PostSaveRecordedSummaryCard(
                            entry: entriesAfterSave.first,
                            allEntries: entriesAfterSave,
                            degradedBodyCopy: _lastCaptureLowQualityTranscript
                                ? VoiceCaptureCopy.lowQualityTranscriptIssue
                                : null,
                            showSilentInputWarning: _lastCaptureLikelySilentInput,
                            showAnalysisPendingNote: false,
                            mirror: postSaveDailyMirror,
                            primaryArchiveResult: postSaveArchiveHierarchy?.kind,
                            onAddWhatYouSaid: _lastSavedEntryIsDegraded
                                ? () => unawaited(
                                      _openPendingTranscriptRecoveryForLastVoiceEntry(),
                                    )
                                : null,
                            onCorrectTranscript:
                                _lastSavedEntry != null &&
                                    !_lastSavedEntryIsDegraded &&
                                    TranscriptCorrectionGate.entryAllowsCorrection(
                                      _lastSavedEntry!,
                                    )
                                ? () => unawaited(
                                      _openCorrectTranscriptForEntry(
                                        _lastSavedEntry!,
                                      ),
                                    )
                                : null,
                            onAddMoreDetail: suppressLatestSaveArchiveInsight
                                ? () => unawaited(
                                      navigateToTypeInsteadCapture(
                                        context,
                                        onSaved: _finishSuccessfulCapture,
                                      ),
                                    )
                                : null,
                            onBackToRecord: suppressLatestSaveArchiveInsight
                                ? _resetPostSaveToReady
                                : null,
                          ),
                          if (MomentQualityFeedbackGates.shouldShow(
                            entry: entriesAfterSave.first,
                            showFirstProofMoment: showFirstProofMoment,
                            hierarchyAllowsFeedback:
                                (postSaveArchiveHierarchy?.showMomentQualityFeedback ??
                                    true) &&
                                !showComeBackTomorrowV2PostSave,
                          )) ...[
                            MomentQualityFeedbackCard(
                              entry: entriesAfterSave.first,
                            ),
                          ],
                          if (showFirstProofPayoff &&
                              firstProofPayoffCandidate != null) ...[
                            const SizedBox(height: 16),
                            FirstProofPayoffCard(
                              payoff: firstProofPayoffCandidate,
                              entryCount: postSaveEntryCount,
                              patternConfidence: firstProofPatternConfidence,
                              suppressCtas: firstProofActionLoopContent != null,
                              showProPackagingBridge: !showProEvidenceValuePostSave,
                              onWatchThisNext: _handleFirstProofWatchThisNext,
                              onViewPatternDetails:
                                  firstProofPayoffCandidate.canShowPatternDetail
                                      ? _openFirstProofPatternDetail
                                      : null,
                            ),
                            if (BetaProofFeedbackEngine.shouldShowOnFirstProofPayoff(
                              showFirstProofPayoff: showFirstProofPayoff,
                              firstProofPayoffVisible: true,
                              entryCount: postSaveEntryCount,
                              hasConfirmedRepeat:
                                  EarlyFirstSignalEngine
                                      .hasConfirmedRepeatFoundation(
                                entriesAfterSave,
                              ),
                              isRecording: ui == RecordUiState.recording,
                              isPostSaveDegraded: entriesAfterSave.isNotEmpty &&
                                  VoiceCaptureQuality.isDegradedVoiceCapture(
                                    entriesAfterSave.last,
                                  ),
                              whatChangedQuestionActive: showWhatChangedV2,
                              patternReviewInboxHasActiveItems:
                                  patternReviewInboxActivePostSave,
                            ))
                              BetaProofFeedbackRow(
                                surface: BetaProofFeedbackSurface.firstProofPayoff,
                                source: 'record_post_save',
                                entryCount: postSaveEntryCount,
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine
                                        .hasConfirmedRepeatFoundation(
                                  entriesAfterSave,
                                ),
                                parentVisible: true,
                                isRecording: ui == RecordUiState.recording,
                                isPostSaveDegraded:
                                    entriesAfterSave.isNotEmpty &&
                                        VoiceCaptureQuality
                                            .isDegradedVoiceCapture(
                                          entriesAfterSave.last,
                                        ),
                                whatChangedQuestionActive: showWhatChangedV2,
                                patternReviewInboxHasActiveItems:
                                    patternReviewInboxActivePostSave,
                                onChanged: () => setState(() {}),
                              ),
                            if (showProofQualityResponseOnFirstProofPayoff) ...[
                              const SizedBox(height: 12),
                              ProofQualityResponseCard(
                                result: proofQualityResponseFirstProofCandidate,
                                source: 'record_post_save',
                                onChanged: () => setState(() {}),
                              ),
                            ] else if (showProofSpecificityBoostOnFirstProofPayoff) ...[
                              const SizedBox(height: 12),
                              ProofSpecificityBoostCard(
                                result: proofSpecificityBoostPostSaveCandidate,
                                surface:
                                    ProofSpecificityBoostSurface.firstProofPayoff,
                                source: 'record_post_save',
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine
                                        .hasConfirmedRepeatFoundation(
                                  entriesAfterSave,
                                ),
                                proofKey: CurrentRelevanceStore.proofKeyFor(
                                  entriesAfterSave,
                                ),
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ],
                          if (showTimelineProofMomentOnFirstProofPayoff &&
                              timelineProofMomentPostSaveCandidate != null) ...[
                            const SizedBox(height: 12),
                            TimelineProofMomentCard(
                              result: timelineProofMomentPostSaveCandidate,
                              source: 'record_post_save_first_proof',
                            ),
                            if (BetaProofFeedbackEngine.shouldShow(
                              surface: BetaProofFeedbackSurface.timelineProofMoment,
                              parentVisible: true,
                              entryCount: postSaveEntryCount,
                              hasConfirmedRepeat:
                                  EarlyFirstSignalEngine
                                      .hasConfirmedRepeatFoundation(
                                entriesAfterSave,
                              ),
                              isRecording: ui == RecordUiState.recording,
                              isPostSaveDegraded: entriesAfterSave.isNotEmpty &&
                                  VoiceCaptureQuality.isDegradedVoiceCapture(
                                    entriesAfterSave.last,
                                  ),
                              whatChangedQuestionActive: showWhatChangedV2,
                              patternReviewInboxHasActiveItems:
                                  patternReviewInboxActivePostSave,
                            ))
                              BetaProofFeedbackRow(
                                surface:
                                    BetaProofFeedbackSurface.timelineProofMoment,
                                source: 'record_post_save_first_proof',
                                entryCount: postSaveEntryCount,
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine
                                        .hasConfirmedRepeatFoundation(
                                  entriesAfterSave,
                                ),
                                parentVisible: true,
                                isRecording: ui == RecordUiState.recording,
                                isPostSaveDegraded:
                                    entriesAfterSave.isNotEmpty &&
                                        VoiceCaptureQuality
                                            .isDegradedVoiceCapture(
                                          entriesAfterSave.last,
                                        ),
                                whatChangedQuestionActive: showWhatChangedV2,
                                patternReviewInboxHasActiveItems:
                                    patternReviewInboxActivePostSave,
                                onChanged: () => setState(() {}),
                              ),
                            if (showProofQualityResponseOnTimelineProofPostSave) ...[
                              const SizedBox(height: 12),
                              ProofQualityResponseCard(
                                result:
                                    proofQualityResponseTimelinePostSaveCandidate,
                                source: 'record_post_save_first_proof',
                                onChanged: () => setState(() {}),
                              ),
                            ] else if (showProofSpecificityBoostOnTimelineProofPostSave) ...[
                              const SizedBox(height: 12),
                              ProofSpecificityBoostCard(
                                result: proofSpecificityBoostPostSaveCandidate,
                                surface:
                                    ProofSpecificityBoostSurface.timelineProofMoment,
                                source: 'record_post_save_first_proof',
                                hasConfirmedRepeat:
                                    EarlyFirstSignalEngine
                                        .hasConfirmedRepeatFoundation(
                                  entriesAfterSave,
                                ),
                                proofKey: CurrentRelevanceStore.proofKeyFor(
                                  entriesAfterSave,
                                ),
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ],
                          if (showProofSpecificityOnFirstProofPayoff &&
                              proofSpecificityPostSaveCandidate.shouldShow) ...[
                            const SizedBox(height: 12),
                            ProofSpecificityCard(
                              result: proofSpecificityPostSaveCandidate,
                            ),
                          ],
                          if (showProEvidenceValuePostSave) ...[
                            const SizedBox(height: 12),
                            ProEvidenceValueCard(
                              surface:
                                  ProEvidenceValueSurface.recordPostSaveAfterPayoff,
                              entryCount: postSaveEntryCount,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_post_save_pro_evidence_value',
                              ),
                              onDismiss: () =>
                                  unawaited(_dismissProEvidenceValueBridge()),
                            ),
                          ] else if (showProLockMomentPostSave) ...[
                            const SizedBox(height: 12),
                            ProLockMomentCard(
                              entryCount: postSaveEntryCount,
                              hasFirstProof: true,
                              hasConfirmedRepeat:
                                  EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                                entriesAfterSave,
                              ),
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource: 'record_post_save_pro_lock_moment',
                              ),
                              onDismiss: () => unawaited(_dismissProLockMoment()),
                            ),
                          ] else if (showMonthlyPrivateReportPreviewPostSave &&
                              monthlyPrivateReportPreviewPostSave != null) ...[
                            const SizedBox(height: 12),
                            MonthlyPrivateReportPreviewCard(
                              surface:
                                  MonthlyPrivateReportSurface.recordPostSaveAfterProof,
                              entryCount: postSaveEntryCount,
                              preview: monthlyPrivateReportPreviewPostSave,
                              onSeePro: () => _openProEvidenceValueSubscription(
                                analyticsSource:
                                    'record_post_save_monthly_private_report_preview',
                              ),
                              onDismiss: () => unawaited(
                                _dismissMonthlyPrivateReportPreview(),
                              ),
                            ),
                          ],
                          if (betaFeedbackIntelligenceSurfacePostSave != null) ...[
                            const SizedBox(height: 12),
                            BetaFeedbackIntelligenceCard(
                              surface: betaFeedbackIntelligenceSurfacePostSave,
                              entryCount: postSaveEntryCount,
                              reachedFirstProof: showFirstProofPayoff &&
                                  firstProofPayoffCandidate != null,
                              onSubmitted: () {
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                          if (showFirstProofTruth) ...[
                            const SizedBox(height: 12),
                            FirstProofTruthCard(
                              proofKey: firstProofTruthProofKey,
                              entryCount: postSaveEntryCount,
                              hasSnippets:
                                  firstProofPayoffCandidate!.hasSnippets,
                              onAnswered: () {
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                          if (firstProofActionLoopContent != null) ...[
                            const SizedBox(height: 12),
                            FirstProofActionLoopCard(
                              content: firstProofActionLoopContent,
                              entryCount: postSaveEntryCount,
                              onWatchThisNext: _handleFirstProofWatchThisNext,
                              onViewPatternDetails:
                                  firstProofActionLoopContent
                                          .canShowPatternDetails
                                      ? _openFirstProofPatternDetail
                                      : null,
                              onRenamePattern:
                                  firstProofActionLoopContent.canRenamePattern
                                      ? _openFirstProofRenamePattern
                                      : null,
                              onKeepRecording: _keepRecording,
                              onCorrectTranscript: firstProofActionLoopContent
                                      .canCorrectTranscript
                                  ? () {
                                      final entry = entriesAfterSave.last;
                                      unawaited(
                                        _openCorrectTranscriptForEntry(entry),
                                      );
                                    }
                                  : null,
                              onRemoveFromPattern: firstProofActionLoopContent
                                      .canRemoveFromPattern
                                  ? () => unawaited(
                                        _excludeLatestFromFirstProofPattern(),
                                      )
                                  : null,
                              onOpenPatternCorrection:
                                  firstProofActionLoopContent
                                          .canShowPatternCorrection
                                      ? () => unawaited(
                                            _openFirstProofPatternCorrection(),
                                          )
                                      : null,
                            ),
                          ],
                          if (confirmedRepeatTriggerPayoff != null) ...[
                            const SizedBox(height: 16),
                            ConfirmedRepeatTriggerPayoffCard(
                              payoff: confirmedRepeatTriggerPayoff,
                              analyticsSurface: 'record',
                              entryCount: entriesAfterSave.length,
                              entriesForWhy: entriesAfterSave,
                              onKeepWatching: _resetPostSaveToReady,
                              onViewEvidence: () => context.push(
                                BeliefEvidenceNavigation.route,
                              ),
                            ),
                          ],
                          if (confirmedRepeatHelpfulActionPayoff != null) ...[
                            const SizedBox(height: 16),
                            ConfirmedRepeatHelpfulActionPayoffCard(
                              payoff: confirmedRepeatHelpfulActionPayoff,
                              analyticsSurface: 'record',
                              entryCount: entriesAfterSave.length,
                              entriesForWhy: entriesAfterSave,
                              onKeepWatching: _resetPostSaveToReady,
                              onViewEvidence: () => context.push(
                                BeliefEvidenceNavigation.route,
                              ),
                            ),
                          ],
                          if (confirmedRepeatChangeNotice != null) ...[
                            const SizedBox(height: 16),
                            ConfirmedRepeatChangeNoticeCard(
                              notice: confirmedRepeatChangeNotice,
                              analyticsSurface: 'record',
                              entryCount: entriesAfterSave.length,
                              entriesForWhy: entriesAfterSave,
                              onRecordWhatHelped: () {
                                ConfirmedRepeatHelpfulActionCapture.armForNextSave();
                                setState(
                                  () => _selectedPromptLine =
                                      confirmedRepeatChangeNotice
                                          .guidedRecordPrompt,
                                );
                                _resetPostSaveToReady();
                              },
                              onViewEvidence: () => context.push(
                                BeliefEvidenceNavigation.route,
                              ),
                            ),
                          ],
                          if (repeatReturnCheckOffer != null &&
                              !showReturnCheckPayoff &&
                              !showWhatChangedV2) ...[
                            const SizedBox(height: 12),
                            RepeatReturnCheckCard(
                              entryId: repeatReturnCheckOffer.entryId,
                              entryCount: repeatReturnCheckOffer.entryCount,
                              surface: 'record',
                              onChanged: () {
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                          if (postSaveArchiveHierarchy?.showMomentQualityFeedback ??
                              true)
                            Builder(
                              builder: (context) {
                                if (suppressLatestSaveArchiveInsight) {
                                  return const SizedBox.shrink();
                                }
                                final returnTrigger =
                                    const CapacityReturnTriggerEngine()
                                        .buildFromJournal(
                                  entries: entriesAfterSave,
                                  capacityLoopActive:
                                      _activeLoop?.isCapacityYes ?? false,
                                  capacityCohortActive: false,
                                  surface:
                                      CapacityReturnTriggerSurface.completion,
                                  sampleMode: false,
                                  screenshotMode: ScreenshotMode.enabled,
                                );
                                if (!returnTrigger.showCard) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    CapacityReturnTriggerCard(
                                      result: returnTrigger,
                                      onPrimaryDismiss: _resetPostSaveToReady,
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                        if (postSaveArchiveHierarchy?.showBeliefUpdateCard ==
                                true &&
                            beliefUpdatePayoff != null &&
                            !showFirstProofMoment &&
                            !showReturnCheckPayoff &&
                            !showWhatChangedV2) ...[
                          const SizedBox(height: 16),
                          BeliefUpdatePayoffCard(
                            payoff: beliefUpdatePayoff,
                            showInlineActions: false,
                            onAddAnother: _goToRecordTab,
                            onViewEvidence: () =>
                                context.push(BeliefEvidenceNavigation.route),
                          ),
                        ],
                        if (postSaveArchiveHierarchy != null &&
                            postSaveArchiveHierarchy.showFocusedActionsBar &&
                            !suppressNoisyFirstSaveCards &&
                            !suppressEarlyRepeatPayoffCompetitors &&
                            !showFirstProofMoment &&
                            !showReturnCheckPayoff &&
                            !showWhatChangedV2) ...[
                          const SizedBox(height: 16),
                          PostSaveFocusedActionsBar(
                            onViewEvidence: () =>
                                context.push(BeliefEvidenceNavigation.route),
                            onViewPatterns: () => context.go('/archive-belief'),
                            onAddOneMoreMoment: _goToRecordTab,
                          ),
                        ],
                        if (returnLoopPayoff != null &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          DayTwoReturnLoopCard(
                            payoff: returnLoopPayoff,
                            onAddAnother: () =>
                                unawaited(_onRecordPressed(source: 'main')),
                            onViewArchive: () => context.go('/archive-belief'),
                            onReminderAccepted: () async {
                              await RecordReturnProStore.instance()
                                  .markReturnCueResolved(
                                RecordReturnProReturnCueMethod.reminder,
                              );
                              if (!mounted) return;
                              setState(() {
                                _offerDayTwoReminder = false;
                                _recordReturnProState =
                                    _recordReturnProState?.copyWith(
                                  returnCueResolved: true,
                                  returnCueMethod:
                                      RecordReturnProReturnCueMethod.reminder,
                                );
                              });
                            },
                            onReminderDeclined: () async {
                              await RecordReturnProStore.instance()
                                  .markReturnCueResolved(
                                RecordReturnProReturnCueMethod.localCue,
                              );
                              if (!mounted) return;
                              setState(() {
                                _offerDayTwoReminder = false;
                                _recordReturnProState =
                                    _recordReturnProState?.copyWith(
                                  returnCueResolved: true,
                                  returnCueMethod:
                                      RecordReturnProReturnCueMethod.localCue,
                                );
                              });
                            },
                          ),
                        ],
                        if (_languageCode != 'en') ...[
                          const SizedBox(height: 12),
                          LanguageIndicatorChip(
                            languageCode: _languageCode,
                            detectedCode: _detectedLanguageCode,
                            onSelected: _onLanguageSelected,
                          ),
                        ],
                        // Record → Return → Pro: evidence, return cue,
                        // Pro bridge — after the save succeeded, never blocking.
                        if (justSavedFirstEntry && entriesAfterSave.isNotEmpty) ...[
                          if (!VoiceCaptureQuality.isDegradedVoiceCapture(
                            entriesAfterSave.first,
                          )) ...[
                            const SizedBox(height: 16),
                            const FirstEntrySavedReceiptCard(),
                          ],
                          const SizedBox(height: 16),
                          FirstSaveEvidenceCard(
                            onViewArchive: () => context.go('/archive-belief'),
                            onRecordAnother: () =>
                                unawaited(_onRecordPressed(source: 'main')),
                          ),
                          if (_recordReturnCueVisible &&
                              _journalEntryCount != 1 &&
                              returnLoopPayoff == null) ...[
                            const SizedBox(height: 16),
                            TomorrowReturnCueCard(
                              reminderAvailable: _offerDayTwoReminder,
                              onLocalCue: _acceptRecordReturnLocalCue,
                              onRemind: _acceptRecordReturnReminder,
                            ),
                          ],
                          if (_recordReturnProState != null &&
                              RecordReturnProGates.showProBridge(
                                entryCount: _journalEntryCount,
                                resolved:
                                    _recordReturnProState!.proBridgeResolved,
                                isPro: _recordReturnProIsPro,
                                hasArchiveProof: false,
                              )) ...[
                            const SizedBox(height: 16),
                            ProValueClarityCard(
                              entryCount: _journalEntryCount,
                              source: 'record',
                              onSeePro: () =>
                                  _resolveRecordReturnProBridge(seePro: true),
                              onNotNow: () =>
                                  _resolveRecordReturnProBridge(seePro: false),
                            ),
                          ],
                        ],
                        if (_saveReceipt != null &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          StartHereSaveReceiptCard(
                            receipt: _saveReceipt!,
                            onDismiss: () =>
                                setState(() => _saveReceipt = null),
                          ),
                        ] else if (_suggestionProNudgeSource != null &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          _SuggestionProNudgeCard(
                            onUnlock: () {
                              final source = _suggestionProNudgeSource!;
                              setState(() => _suggestionProNudgeSource = null);
                              context.push(
                                '/subscription',
                                extra: PaywallRouteArgs(
                                  source: source,
                                  sourceRoute: '/record',
                                ),
                              );
                            },
                            onDismiss: () => setState(
                              () => _suggestionProNudgeSource = null,
                            ),
                          ),
                        ],
                        if (_doneForTodayReceipt != null &&
                            _doneForTodayReceipt!.hasReceipt &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          DoneForTodayReceiptCard(
                            receipt: showFirstProofMoment
                                ? _doneForTodayReceipt!.copyWith(
                                    archiveLine: '',
                                  )
                                : _doneForTodayReceipt!,
                          ),
                          // 2-day path day-1 closure: only after the very
                          // first save, alongside (never instead of) the
                          // Done for today receipt.
                          Builder(
                            builder: (context) {
                              final path = const TwoDayActivationEngine()
                                  .buildPostSave(entryCount: _journalEntryCount);
                              if (!path.show || returnLoopPayoff != null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: TwoDayActivationCard(path: path),
                              );
                            },
                          ),
                          // One optional day-2 reminder offer — first save
                          // only, below (never instead of) the receipt. The
                          // First 60 return cue carries the same single
                          // reminder offer, so the two never show together.
                          if (_offerDayTwoReminder &&
                              !_recordReturnCueVisible &&
                              returnLoopPayoff == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: DayTwoReminderCard(),
                            ),
                          // Tomorrow's-check preview — passive, no CTA,
                          // safe labels only.
                          if (_dayTwoReturnPreview != null &&
                              _dayTwoReturnPreview!.show &&
                              returnLoopPayoff == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: DayTwoReturnPreviewCard(
                                preview: _dayTwoReturnPreview!,
                                entryCount: _journalEntryCount,
                              ),
                            ),
                        ],
                        if (_archiveProofCounter != null &&
                            PostSaveCompletionCopyGates.showArchiveProofCounter(
                              counterHasProof: _archiveProofCounter!.hasProof,
                              doneReceiptVisible:
                                  _doneForTodayReceipt != null &&
                                  _doneForTodayReceipt!.hasReceipt,
                              suppressNoisyFirstSaveCards:
                                  suppressNoisyFirstSaveCards,
                            )) ...[
                          const SizedBox(height: 16),
                          ArchiveProofCounterCard(
                            counter: _archiveProofCounter!,
                          ),
                        ],
                        if (shareableProof != null &&
                            shareableProof.hasProof &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ShareableArchiveProofCard(proof: shareableProof),
                        ],
                        if (_valueMomentBridge != null &&
                            _valueMomentBridge!.show &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ValueMomentProBridge(
                            bridge: _valueMomentBridge!,
                            onSeePro: () {
                              setState(() => _valueMomentBridge = null);
                              context.push(
                                '/subscription',
                                extra: PaywallRouteArgs(
                                  source: PaywallSource.valueMoment,
                                  sourceRoute: '/record',
                                ),
                              );
                            },
                            onDismiss: () => setState(() {
                              ValueMomentPaywallTrigger.dismissedThisSession =
                                  true;
                              _valueMomentBridge = null;
                            }),
                          ),
                        ],
                        if (_showEvidenceContextTag &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          CaptureContextTagCard(
                            onSaveTag: _saveEvidenceContextTag,
                            onSkip: () =>
                                setState(() => _showEvidenceContextTag = false),
                          ),
                        ],
                        if (stack.showInputQualityCoach &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          InputQualityCoachCard(
                            result: _inputQuality!,
                            originalText: _inputQualityText,
                            onAddSentence: _onInputQualityAddSentence,
                            onUseAnyway: _onInputQualityUseAnyway,
                            languageCode: _languageCode,
                          ),
                        ],
                        if (!stack.showInputQualityCoach &&
                            stack.showCompletedResult &&
                            _returnDayJustClosed &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          ReturnDayClosedCard(
                            resultHeadline:
                                _completedCheckInToday!.resultHeadline,
                            usefulLine: _completedCheckInToday!.whatThisMeans,
                            nextCheck:
                                _completedCheckInToday!.tomorrowsBetterQuestion,
                            onDone: () =>
                                setState(() => _returnDayJustClosed = false),
                            onRecordAnother: _keepRecording,
                          ),
                          // First session never reaches here; only surface a fresh
                          // progress moment so the payoff stays one card deep.
                          if (stack.showArchiveProofCards &&
                              _patternProgress != null) ...[
                            const SizedBox(height: 16),
                            PatternProgressAfterSaveCard(
                              progress: _patternProgress!,
                            ),
                          ],
                        ] else if (!stack.showInputQualityCoach &&
                            stack.showCompletedResult &&
                            !suppressNoisyFirstSaveCards) ...[
                          const SizedBox(height: 16),
                          CheckInCompletedCard(
                            checkIn: _completedCheckInToday!,
                            weakInput: _weakInput,
                            languageCode: _languageCode,
                            betterResultIntensity:
                                ScreenshotMode.screenshotBetterResult
                                ? ScreenshotMode.screenshotBetterResultIntensity
                                : ScreenshotMode.completedCheckInPreview
                                ? HookRescueIntensity.elevated
                                : _hookRescue?.intensityFor(
                                        HookRescueAction.betterResult,
                                      ) ??
                                      HookRescueIntensity.normal,
                            notUsefulReason: _hookRescueNotUsefulReason,
                            nextCheckSlot: stack.showResultNextCheck
                                ? ResultNextCheckCard(
                                    checkIn: _completedCheckInToday!,
                                    notUsefulReason: _hookRescueNotUsefulReason,
                                    feedbackHint: _feedbackHint,
                                    showFeedback: stack.showFeedback,
                                    routineAnchorPicker: stack.showRoutineAnchor
                                        ? () =>
                                              RoutineAnchorChooser.show(context)
                                        : null,
                                    onRoutineAnchorChosen:
                                        stack.showRoutineAnchor
                                        ? (anchor) =>
                                              RoutineAnchorStore.instance()
                                                  .saveForDate(
                                                    _tomorrowDateKey,
                                                    anchor,
                                                  )
                                        : null,
                                    onCreateCheckIn: (question) async {
                                      await TomorrowCheckInCoordinator.createForTomorrow(
                                        patternTitle: _completedCheckInToday!
                                            .patternTitle,
                                        specificPrompt:
                                            _completedCheckInToday!.prompt,
                                        checkInQuestion: question,
                                      );
                                      final anchor =
                                          await RoutineAnchorStore.instance()
                                              .loadForDate(_tomorrowDateKey);
                                      final active =
                                          await TomorrowCheckInCoordinator.loadActive();
                                      if (active != null) {
                                        await RetentionReminderCoordinator.maybeScheduleAfterNextCheckChosen(
                                          active,
                                          hasRoutineAnchor: anchor != null,
                                        );
                                      }
                                      if (!mounted) return;
                                      setState(() {
                                        _retentionNextCheckJustChosen = true;
                                        _retentionDismissed = false;
                                        _activeCheckInForTomorrow = active;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          if (shouldShowKinderAngle(
                            _inputQualityText,
                            resultHint:
                                _completedCheckInToday!.selectedOptionId ??
                                'same',
                          ))
                            KinderAngleCard(
                              reflectionText: _inputQualityText,
                              resultHint:
                                  _completedCheckInToday!.selectedOptionId ??
                                  'same',
                              patternTitle:
                                  _completedCheckInToday!.patternTitle,
                              specificPrompt: _completedCheckInToday!.prompt,
                              languageCode: _languageCode,
                              compact: true,
                            )
                          else
                            PerspectiveShiftCard(
                              reflectionText: _inputQualityText,
                              resultHint:
                                  _completedCheckInToday!.selectedOptionId ??
                                  'same',
                              checkInQuestion: _completedCheckInToday!.question,
                              patternTitle:
                                  _completedCheckInToday!.patternTitle,
                              specificPrompt: _completedCheckInToday!.prompt,
                              languageCode: _languageCode,
                              compact: true,
                            ),
                          if (stack.showArchiveProofCards &&
                              _patternMemory != null) ...[
                            const SizedBox(height: 16),
                            PatternMemoryAfterSaveCard(
                              memory: _patternMemory!,
                              onUseNext:
                                  _patternNextAction == null &&
                                      !suppressPostResultNextCheckCompetitors
                                  ? () => _usePatternMemoryNext(_patternMemory!)
                                  : null,
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _patternProgress != null) ...[
                            const SizedBox(height: 16),
                            PatternProgressAfterSaveCard(
                              progress: _patternProgress!,
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _patternNextAction != null &&
                              !suppressPostResultNextCheckCompetitors) ...[
                            const SizedBox(height: 16),
                            PatternNextActionCard(
                              action: _patternNextAction!,
                              onUse: () =>
                                  _usePatternNextAction(_patternNextAction!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _habitProof != null &&
                              !suppressPostResultNextCheckCompetitors) ...[
                            const SizedBox(height: 16),
                            HabitProofCard(
                              proof: _habitProof!,
                              onKeepGoing: () =>
                                  _keepHabitProofGoing(_habitProof!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _weeklyRecap != null) ...[
                            const SizedBox(height: 16),
                            WeeklyPatternRecapCard(
                              recap: _weeklyRecap!,
                              onUseNext: suppressPostResultNextCheckCompetitors
                                  ? null
                                  : () => _useWeeklyRecapNext(_weeklyRecap!),
                            ),
                          ],
                          if (stack.showArchiveProofCards &&
                              _shareRecap != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _copyShareRecap(_shareRecap!),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy recap'),
                              ),
                            ),
                          ],
                        ],
                        if (!stack.showInputQualityCoach &&
                            _tomorrowReturnLoop != null &&
                            !_returnDayJustClosed &&
                            !suppressNoisyFirstSaveCards &&
                            !suppressEarlyPatternClaimCards &&
                            !suppressEarlyRepeatPayoffCompetitors &&
                            !showFirstProofMoment &&
                            !showReturnCheckPayoff &&
                            !showWhatChangedV2) ...[
                          if (_secondSessionComparison?.hasEnoughData == true &&
                              secondSessionPayoff == null) ...[
                            const SizedBox(height: 12),
                            SecondSessionComparisonCard(
                              comparison: _secondSessionComparison!,
                              onGoDeeper: () {
                                final prompt =
                                    _secondSessionComparison!.whatToTestNext;
                                if (prompt == null || prompt.isEmpty) return;
                                unawaited(_onSecondSessionEvidence(prompt));
                              },
                              onRecordNextEvidence: () {
                                final prompt =
                                    _secondSessionComparison!.whatToTestNext;
                                if (prompt == null || prompt.isEmpty) return;
                                unawaited(_onSecondSessionEvidence(prompt));
                              },
                              onNotTheSame: () => setState(
                                () => _secondSessionComparison = null,
                              ),
                            ),
                          ],
                          if (!_patternHypothesisDismissed &&
                              _patternHypothesis?.hasEnoughData == true) ...[
                            const SizedBox(height: 12),
                            PatternHypothesisCard(
                              hypothesis: _patternHypothesis!,
                              onFeelsRight: () async {
                                final selected =
                                    await SelectedSignalCoordinator.loadCurrent();
                                if (selected != null) {
                                  await SignalFeedbackCoordinator.track(
                                    action: PostSaveSignalAction.accepted,
                                    signalId: selected.id,
                                    signalTitle: selected.title,
                                    categoryId: selected.categoryId,
                                  );
                                }
                                if (!mounted) return;
                                setState(
                                  () => _patternHypothesisDismissed = true,
                                );
                              },
                              onNotMe: () async {
                                final selected =
                                    await SelectedSignalCoordinator.loadCurrent();
                                if (selected != null) {
                                  await SignalFeedbackCoordinator.track(
                                    action: PostSaveSignalAction.rejected,
                                    signalId: selected.id,
                                    signalTitle: selected.title,
                                    categoryId: selected.categoryId,
                                  );
                                }
                                if (!mounted) return;
                                setState(
                                  () => _patternHypothesisDismissed = true,
                                );
                              },
                              onRecordNext: () => _keepRecording(
                                nextEvidencePrompt:
                                    _patternHypothesis!.watchNext,
                              ),
                              onViewArchive: () =>
                                  context.go('/archive-belief'),
                            ),
                          ],
                          if (_postSavePattern != null) ...[
                            const SizedBox(height: 12),
                            PostSaveInsightChoiceCard(
                              pattern: _postSavePattern!,
                              entry: _lastSavedEntry,
                              priorEntries: _entriesAfterSave.length > 1
                                  ? _entriesAfterSave.sublist(1)
                                  : const [],
                              feedback: _postSaveInsightFeedback,
                              selectedSignal: _postSaveSelectedSignal,
                              audienceWedge: _audienceWedge,
                              activeLoop: _activeLoop,
                              reflectionCount: _entriesAfterSave.length.clamp(
                                1,
                                3,
                              ),
                              categoryRepeated:
                                  _secondSessionComparison?.possibleRepeat ==
                                  true,
                              entryId: _lastSavedEntry?.id,
                              onSaveSignal: (pattern) async {
                                if (_isFirstSessionPostSave) {
                                  final thread =
                                      await FirstSessionCoordinator.acceptForTomorrow(
                                        pattern,
                                        reflectionText:
                                            _lastSavedEntry?.transcript ?? '',
                                        sourceReflectionId: _lastSavedEntry?.id,
                                      );
                                  if (!mounted) return;
                                  if (TrialMode.enabled) {
                                    _watchForAcceptPending = false;
                                    await ActivationTracker.clearWatchForAcceptPending();
                                  }
                                  setState(() => _activePatternThread = thread);
                                }
                              },
                              onUsePrompt: _saveNextEvidencePrompt,
                              onRecordNext: _keepRecording,
                              onRecordNextEvidence: (prompt) =>
                                  _keepRecording(nextEvidencePrompt: prompt),
                              onViewPatterns: () =>
                                  context.go('/archive-belief'),
                            ),
                          ] else if (_isFirstSessionPostSave) ...[
                            const SizedBox(height: 12),
                            FirstReflectionResultCard(
                              onRecordAnother: _keepRecording,
                              onViewPatterns: () =>
                                  context.go('/archive-belief'),
                            ),
                          ] else ...[
                            if (_activePatternThread != null &&
                                _completedWatchForToday != null) ...[
                              const SizedBox(height: 12),
                              ActivePatternThreadCard(
                                thread: _activePatternThread!,
                                compact: true,
                              ),
                            ],
                            if (_completedWatchForToday != null) ...[
                              const SizedBox(height: 12),
                              WatchForResultCard(
                                completed: _completedWatchForToday!,
                                headline: ScreenshotMode.enabled
                                    ? ScreenshotSampleData
                                          .watchForCompletedHeadline
                                    : null,
                                body: ScreenshotMode.enabled
                                    ? ScreenshotSampleData.watchForCompletedBody
                                    : null,
                              ),
                            ],
                            if (_postSavePattern == null) ...[
                              const SizedBox(height: 12),
                              PotentialSignalsCard(
                                signals: _postSaveSignals(),
                                noticedToday: _tomorrowReturnLoop!.noticedToday,
                                showPatternHint:
                                    _postSaveShowsPossiblePattern(),
                              ),
                            ],
                            if (_firstThreeJourney != null &&
                                !_firstThreeJourney!.completed &&
                                _showFirstThreeJourneyOnRecord) ...[
                              const SizedBox(height: 12),
                              FirstThreeJourneyCard(
                                model: _firstThreeJourney!,
                                compact: true,
                              ),
                            ],
                            if (_showAdvancedRetentionPostSave) ...[
                              if (_returnComparison != null) ...[
                                const SizedBox(height: 12),
                                ReturnComparisonCard(
                                  comparison: _returnComparison!,
                                ),
                              ],
                              if (_returnStreak != null &&
                                  _journalEntryCount >= 2 &&
                                  _returnStreak!.currentStreakDays >= 2) ...[
                                const SizedBox(height: 12),
                                ReturnStreakCard(
                                  streak: _returnStreak!,
                                  showCta: false,
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            TomorrowReturnCard(loop: _tomorrowReturnLoop!),
                            if (_suggestedWatchForTomorrow != null) ...[
                              const SizedBox(height: 12),
                              WatchForTomorrowCard(
                                suggestion: _suggestedWatchForTomorrow!,
                                onChooseAnother: () {
                                  setState(() {
                                    _watchForAlternativeIndex =
                                        (_watchForAlternativeIndex + 1) % 3;
                                    _suggestedWatchForTomorrow =
                                        WatchForCoordinator.buildSuggestedWatchForAfterSave(
                                          entries: _entriesAfterSave,
                                          loop: _tomorrowReturnLoop,
                                          signals: _postSaveSignals(),
                                          alternativeIndex:
                                              _watchForAlternativeIndex,
                                        );
                                  });
                                },
                              ),
                            ],
                            if (_showAdvancedRetentionPostSave) ...[
                              const SizedBox(height: 16),
                              TomorrowCommitmentCard(
                                loop: _tomorrowReturnLoop!,
                              ),
                            ],
                          ],
                        ],
                      ],
                      if (_localSaveTitle != null && !_lastSavedEntryIsDegraded) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: VoiceMemoryColors.captureSuccess,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localSaveTitle!,
                                    style: VoiceMemoryTypography.cardTitleStyle(
                                      color: VoiceMemoryColors.captureSuccess,
                                    ),
                                  ),
                                  if (syncNote != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      syncNote,
                                      style: const TextStyle(
                                        color: VoiceMemoryColors.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    if (showCoreValueFeedbackOnRecordPostFirstProof) ...[
                      CoreValueFeedbackCard(
                        source: CoreValueFeedbackSource.recordPostFirstProof,
                        entryCount: postSaveEntryCount,
                        hasConfirmedRepeat: postSaveHasConfirmedRepeat,
                        hasFirstProof: postSaveHasFirstProof,
                        onChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showWhatChangedV2Display && whatChangedV2Display != null) ...[
                      WhatChangedV2Card(
                        key: ValueKey(whatChangedV2Display.entryId),
                        prompt: whatChangedV2Display,
                        source: 'record_post_save',
                        onSomethingHelped: () {
                          if (mounted) setState(() {});
                        },
                        onChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showHelpedTracking && helpedTrackingPrompt != null) ...[
                      HelpedTrackingCard(
                        key: ValueKey(helpedTrackingPrompt.entryId),
                        prompt: helpedTrackingPrompt,
                        source: 'record_post_save',
                        onChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showReturnCheckPayoff &&
                        returnCheckPayoffCandidate != null) ...[
                      ReturnCheckPayoffCard(
                        payoff: returnCheckPayoffCandidate,
                        entryCount: postSaveEntryCount,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showFirstWeekProgressPostSave &&
                        firstWeekProgressPostSave != null) ...[
                      FirstWeekProgressLine(
                        progress: firstWeekProgressPostSave,
                        entryCount: postSaveEntryCount,
                        surface: 'record_post_save',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showComeBackTomorrowV2PostSave &&
                        comeBackTomorrowV2PostSaveWatch != null) ...[
                      ComeBackTomorrowCard(
                        watch: comeBackTomorrowV2PostSaveWatch,
                        entryCount: postSaveEntryCount,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showReturnTomorrowCuePostSave &&
                        returnTomorrowCuePostSave != null) ...[
                      ReturnTomorrowCueCard(
                        cue: returnTomorrowCuePostSave,
                        entryCount: postSaveEntryCount,
                        surface: 'record_post_save',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (showPostSaveReturnHandoff &&
                        postSaveReturnHandoffCandidate != null) ...[
                      PostSaveReturnHandoffCard(
                        handoff: postSaveReturnHandoffCandidate,
                        entryCount: postSaveEntryCount,
                      ),
                      const SizedBox(height: 16),
                    ],
                    ..._buildBottomActions(
                      context,
                      ui: ui,
                      canRecord: canRecord,
                      localSaveTitle: localSaveTitle,
                      selectedPrompt: _selectedPromptLine,
                      suppressDuplicateRecordCtas:
                          stack.suppressDuplicateRecordCtas,
                      policyMicPhase: policyMic,
                      policyUserDenied: policyUserDenied,
                      recordHomeSurface: recordHomeSurface,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
            if (showCloseButton)
              const Align(
                alignment: Alignment.topRight,
                child: RecordScreenCloseButton(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissFirstSessionOnboarding() async {
    await FirstSessionOnboardingStore.instance().markDismissed();
    if (mounted) setState(() {});
  }

  void _resetPostSaveToReady() {
    setState(() {
      _error = null;
      _localSaveTitle = null;
      _syncNote = null;
      _showPostSaveLoop = false;
      _instantReflectionResponse = null;
      _immediateDiscovery = null;
      _immediateDiscoveryLoading = false;
      _savedFromConfirmedRepeatTrigger = false;
      _savedFromHelpfulAction = false;
      ConfirmedRepeatTriggerCapture.clearSaveReceipt();
      ConfirmedRepeatHelpfulActionCapture.clearSaveReceipt();
      _ui = _uiForMicPhase(_mic);
    });
  }

  List<Widget> _buildPolicyPrimarySecondaryButtons(
    RecordCtaPolicyResolution policy, {
    VoidCallback? onPrimary,
    Key? primaryKey,
  }) {
    final widgets = <Widget>[];
    final primary = policy.primaryLabel;
    if (primary == null || !policy.showMainBottomCta) return widgets;

    widgets.add(
      SizedBox(
        height: 48,
        width: double.infinity,
        child: FilledButton(
          key: primaryKey,
          onPressed: onPrimary ?? _resetPostSaveToReady,
          child: Text(primary),
        ),
      ),
    );

    for (final (index, label) in policy.secondaryLabels.indexed) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              if (label == ConsumerUiCopy.doneCta) {
                _resetPostSaveToReady();
                return;
              }
              if (label == VoiceCaptureCopy.recordAgainCta ||
                  label == ConsumerUiCopy.recordAnotherCta) {
                _resetPostSaveToReady();
                return;
              }
              _resetPostSaveToReady();
            },
            child: Text(label),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildBottomActions(
    BuildContext context, {
    required RecordUiState ui,
    required bool canRecord,
    required String? localSaveTitle,
    String? selectedPrompt,
    required bool suppressDuplicateRecordCtas,
    RecordingPhase? policyMicPhase,
    bool? policyUserDenied,
    RecordHomeSurfacePolicy recordHomeSurface =
        const RecordHomeSurfacePolicy(),
  }) {
    RecordCtaPolicyResolution policyForUi() => _recordCtaPolicy(
      ui,
      micPhase: policyMicPhase,
      userDeniedThisSession: policyUserDenied,
    );
    final actions = <Widget>[];

    if (ui == RecordUiState.permissionBlocked) {
      return actions;
    }
    if (ui == RecordUiState.ready) {
      if (_showBottomRetentionCards) {
        // Invited User Welcome: replaces (never joins) the generic
        // first-session explainer for invited installs, so the pre-first-save
        // screen never gets more crowded. Only before the first save.
        final showInvitedWelcome =
            _invitedWelcomeSource != null && _journalEntryCount == 0;
        if (showInvitedWelcome) {
          actions.add(
            InvitedUserWelcomeCard(
              source: _invitedWelcomeSource!,
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() => _invitedWelcomeSource = null),
            ),
          );
        }
        // Record once intro: zero saved entries only — one supporting line
        // and one record CTA. Leads the stack but never blocks recording.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            RecordOnceIntroCard.shouldShow(_journalEntryCount)) {
          actions.add(
            RecordOnceIntroCard(
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First-session explainer: brand-new users (no entries / no pressure
        // check-ins yet) get a clear, emotionally framed starting point.
        if (_showLegacyEmptyOnboarding &&
            !showInvitedWelcome &&
            FirstSessionExplanationCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSessionExplanationCard(
              onLogPressure: () => context.push('/pressure-check-in'),
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Save Rescue: a 10-second, deletable test recording for users
        // with an empty archive. One CTA into the existing recording flow —
        // sits alongside (never instead of) the explainer above.
        if (_showLegacyEmptyOnboarding &&
            FirstSaveRescueCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstSaveRescueCard(
              onStart: () => unawaited(_onRecordPressed(source: 'main')),
            ),
          );
        }
        // First Recording Sample: one tiny editable starter sentence for an
        // empty archive. The CTA seeds the existing recording flow (the line
        // shows as the "Try saying" helper) — never a new flow, never a list.
        if (_showLegacyEmptyOnboarding &&
            FirstRecordingSampleCard.shouldShow(_journalEntryCount)) {
          actions.add(
            FirstRecordingSampleCard(
              onUseStarter: () =>
                  _onStartHereSelected(FirstRecordingSample.sample),
            ),
          );
        }
        if (RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: _journalEntryCount,
          justSaved: _recordReturnProJustSaved,
          hiddenThisSession: RepeatRecordingNudgeSession.secondEntryHidden,
        )) {
          actions.add(
            SecondEntryNudgeCard(
              source: 'record',
              onRecord: () => unawaited(_onRecordPressed(source: 'main')),
              onDismiss: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards &&
            AhaMomentGates.shouldShow(
              candidate: _ahaCandidate,
              entryCount: _journalEntryCount,
            )) {
          actions.add(
            FirstAhaMomentCard(
              candidate: _ahaCandidate!,
              source: 'record',
              onChanged: () => setState(() {}),
            ),
          );
        }
        if (_showAhaMomentCards && AhaProofShareEligibility.shouldShow) {
          actions.add(
            AhaProofShareCard(
              entryCount: _journalEntryCount,
              source: 'record',
              onDismiss: () => setState(() {}),
            ),
          );
        }
        // Calm 2-day path: the plan before the first save, the return moment
        // on day 2, nothing once the loop is running. Passive — never blocks
        // recording.
        final twoDayPath = const TwoDayActivationEngine().build(
          entryCount: _journalEntryCount,
          entryDates: _entryDates,
        );
        if (twoDayPath.show && _showTwoDayActivationCard) {
          // Invited Day 2 return copy: the second visit matches the reason the
          // user was invited. Replaces (never joins) the generic Day 2 card so
          // the return moment never gets more crowded.
          if (InvitedDayTwoReturn.shouldShow(
            inviteSource: _inviteSource,
            stage: twoDayPath.stage,
          )) {
            actions.add(
              InvitedDayTwoReturnCard(
                source: _inviteSource!,
                entryCount: _journalEntryCount,
                onCheck: () => unawaited(_onRecordPressed(source: 'main')),
              ),
            );
          } else if (twoDayPath.stage == TwoDayActivationStage.dayTwoReturn &&
              RepeatRecordingNudgeGates.showDay2ReturnReason(
                entryCount: _journalEntryCount,
                twoDayPath: twoDayPath,
                hasRealChangeInsight: _hasRealChangeInsight,
                hiddenThisSession: RepeatRecordingNudgeSession.day2Hidden,
              )) {
            actions.add(
              Day2ReturnReasonCard(
                source: 'record',
                onRecord: () => unawaited(_onRecordPressed(source: 'main')),
                memoryOff: MemoryScopePolicy.scope == MemoryScope.off,
                onDismiss: () => setState(() {}),
              ),
            );
          } else if (twoDayPath.stage != TwoDayActivationStage.dayTwoReturn) {
            actions.add(TwoDayActivationCard(path: twoDayPath));
          }
        }
        // Change can begin: two or more entries, no real insight yet, and
        // the generic card has not been seen — passive, never blocks recording.
        if (_recordReturnProState != null &&
            RecordReturnProGates.showChangeCanBegin(
              entryCount: _journalEntryCount,
              changeStartSeen: _recordReturnProState!.changeStartSeen,
              hasRealChangeInsight: _hasRealChangeInsight,
            )) {
          actions.add(
            ChangeStartsCard(
              entryCount: _journalEntryCount,
              onViewArchive: () => context.go('/archive-belief'),
              onSearchArchive: () => context.go('/archive-belief'),
              onSeen: () => unawaited(_markChangeStartSeen()),
            ),
          );
        }
        // Day 7 continuity: after the Day 2 return (2+ entries), a calm note
        // on where the archive is — passive until the existing weekly review
        // is genuinely ready, then a single CTA into it. Never blocks
        // recording.
        final continuityLoop = const DaySevenContinuityEngine().build(
          entryCount: _journalEntryCount,
          hasWeeklyReview: _hasWeeklyReviewForContinuity,
        );
        if (continuityLoop.show && recordHomeSurface.showDaySevenContinuity) {
          actions.add(
            DaySevenContinuityCard(
              loop: continuityLoop,
              entryCount: _journalEntryCount,
              hasConnectedThread: _hasConnectedThreadForContinuity,
              onViewWeeklyReview: () => context.push('/pressure-insights'),
            ),
          );
        }
        // Compact return-trigger reminder for users who accepted it; never
        // shown alongside the first-session card.
        if (PressureReturnTriggerReminder.shouldShow(
          accepted: _returnTriggerAccepted,
          entryCount: _journalEntryCount,
        )) {
          actions.add(
            PressureReturnTriggerReminder(
              onLogPressure: () => context.push('/pressure-check-in'),
            ),
          );
        }
        if (recordHomeSurface.showEntryDirectionStarters) {
          actions.add(
            EntryDirectionStarters(
              selectedPrompt: _selectedPromptLine,
              onSelect: (prompt) {
                ActivationTracker.trackActivationStarterPromptSelected();
                setState(() => _selectedPromptLine = prompt);
              },
            ),
          );
          actions.add(const SizedBox(height: 8));
        }
      }
      final readyPolicy = policyForUi();
      final firstUseSimplifiedRecord =
          RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
      );
      if (!_shouldPromoteMicCaptureActions(readyPolicy) &&
          !firstUseSimplifiedRecord) {
        actions.add(
          _buildCaptureEntryActions(
            context: context,
            selectedPrompt: selectedPrompt,
            policy: readyPolicy,
          ),
        );
      }
      if (recordHomeSurface.showReturnRitual &&
          ReturnRitualGates.showOnRecord(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isPostSave: _isPostSaveSurface,
        isReadyOrIdle: true,
      )) {
        actions.add(
          ReturnRitualCard(
            entryCount: _journalEntryCount,
            onAddMoment: () => unawaited(_onRecordPressed(source: 'main')),
          ),
        );
      }
      if (recordHomeSurface.showArchiveReturnChanges &&
          ArchiveReturnChangesGates.showOnRecord(
        loaded: _journalEntryCountLoaded,
        entryCount: _journalEntryCount,
        isPostSave: _isPostSaveSurface,
        sampleMode: false,
        result: _archiveReturnChangesResult,
      )) {
        actions.add(
          ArchiveReturnChangesCard(
            result: _archiveReturnChangesResult!,
            onMarkSeen: () => unawaited(_markArchiveReturnChangesSeen()),
          ),
        );
      }
      if (recordHomeSurface.showArchiveDepth &&
          ArchiveDepthGates.showCompactOnRecord(
        loaded: _journalEntryCountReady,
        entryCount: _journalEntryCount,
        isPostSave: _isPostSaveSurface,
      )) {
        actions.add(
          ArchiveDepthCompactHint(
            result: const ArchiveDepthEngine().build(
              entries: _journalEntries,
            ),
          ),
        );
      }
      if (_journalEntryCountReady && _journalEntryCount > 0) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
      if (_purchaseIntentCue != null &&
          _showBottomRetentionCards &&
          recordHomeSurface.showProBridge) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PurchaseIntentReturnCueCard(
              intent: _purchaseIntentCue!,
              onSeePro: () {
                final intent = _purchaseIntentCue!;
                setState(() => _purchaseIntentCue = null);
                context.push(
                  '/subscription',
                  extra: PaywallRouteArgs(
                    source:
                        PaywallSource.fromId(intent.source) ??
                        PaywallSource.generalPro,
                    sourceRoute: '/record',
                  ),
                );
              },
              onDismiss: () => setState(() => _purchaseIntentCue = null),
            ),
          ),
        );
      }
    }
    if (ui == RecordUiState.recording) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _stopAndProcess,
            icon: const Icon(Icons.stop),
            label: Text(policyForUi().primaryLabel ?? ConsumerUiCopy.stopRecordingCta),
          ),
        ),
      );
      // Still changeable while recording — the choice applies at save.
      if (_journalEntryCountReady && _journalEntryCount > 0) {
        actions.add(CleanSlatePromptSection(entryCount: _journalEntryCount));
        actions.add(EntryOptionsSection(entryCount: _journalEntryCount));
      }
    }
    // Fresh-entry receipt: only when the save carried "Treat this as new".
    if (ui == RecordUiState.done && TreatAsNew.lastSaveWasFresh) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: FreshEntrySavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        EntryAboutnessSession.lastSaveWasNonPersonal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: NotAboutMeReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasDoNotSurface) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: DoNotSurfaceReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        MemorySurfacingSession.lastSaveWasSensitive) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SensitiveSurfacingReceipt(),
        ),
      );
    }
    // Exact-evidence receipt: only when the save carried "Keep exact details".
    if (ui == RecordUiState.done && KeepExactDetails.lastSaveKeptExact) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ExactDetailsSavedReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        PreserveOriginalSession.lastSavePreservedOriginal) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CuratedMemoryReceipt(),
        ),
      );
    }
    if (ui == RecordUiState.done &&
        ArchiveTrustReceipt.shouldShow(entryCount: _journalEntryCount) &&
        !_lastSavedEntryIsDegraded) {
      actions.add(
        ArchivePrivateReceiptCard(
          entryCount: _journalEntryCount,
          source: 'record',
          onDismiss: () => setState(() {}),
        ),
      );
    }
    if (_showPostSaveLoop && _tomorrowReturnLoop != null) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      );
    } else if (_showPostSaveLoop && _postSaveFollowUp != null) {
      actions.addAll([
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _enoughForNow,
            child: const Text("That's enough for now"),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _keepRecording,
            child: const Text(ConsumerUiCopy.postSaveRecordAnotherReflection),
          ),
        ),
      ]);
    }
    if (ui == RecordUiState.done && !_showPostSaveLoop) {
      final policy = policyForUi();
      if (policy.state == RecordCtaPolicyState.postSaveDegraded) {
        actions.addAll(
          _buildPolicyPrimarySecondaryButtons(
            policy,
            primaryKey: const Key('post_save_type_what_you_said'),
            onPrimary: () => unawaited(_openPendingTranscriptRecoveryForLastVoiceEntry()),
          ),
        );
      } else if (policy.state == RecordCtaPolicyState.postSaveSuccess) {
        actions.addAll(_buildPolicyPrimarySecondaryButtons(policy));
      }
    }
    if (ui == RecordUiState.error) {
      actions.addAll(
        _buildPolicyPrimarySecondaryButtons(policyForUi()),
      );
    }
    if (!canRecord && ui == RecordUiState.idle) {
      actions.add(
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _requestMic,
            child: const Text('Set up microphone'),
          ),
        ),
      );
    }
    return actions;
  }

  String _statusTextFor(RecordUiState ui, String? localSaveTitle) {
    switch (ui) {
      case RecordUiState.permissionBlocked:
        return MicrophonePermissionCopy.statusBlocked;
      case RecordUiState.requestingPermission:
        return 'Allowing microphone access';
      case RecordUiState.ready:
        return 'Ready to record';
      case RecordUiState.recording:
        return 'Recording';
      case RecordUiState.processing:
        return 'Processing';
      case RecordUiState.done:
        return localSaveTitle ?? 'Saved';
      default:
        return 'Recording';
    }
  }
}

/// Gentle post-save Pro nudge shown after a recording that started from a
/// daily suggestion. Dismissible, shows at most once per session, and never
/// appears for Pro users or before three saved entries.
class _SuggestionProNudgeCard extends StatelessWidget {
  const _SuggestionProNudgeCard({
    required this.onUnlock,
    required this.onDismiss,
  });

  final VoidCallback onUnlock;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('suggestion_pro_nudge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your daily archive prompts improving',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ArchiveMe uses what you record to surface sharper things '
            'worth checking each day.',
            style: TextStyle(
              fontSize: 13,
              color: VoiceMemoryColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  // Compact override: the app-wide FilledButton theme is
                  // full-width, which cannot live inside this Row.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onUnlock,
                  child: const Text(
                    'Unlock Pro',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordingStatusCard extends StatelessWidget {
  const _RecordingStatusCard({required this.seconds, required this.stageLabel});

  final int seconds;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timer =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Semantics(
      label: 'Recording in progress, $seconds seconds',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 44, color: VoiceMemoryColors.primaryIndigo),
            const SizedBox(height: 14),
            const IndigoCaptureWaveform(),
            const SizedBox(height: 12),
            Text(
              stageLabel.isEmpty ? 'Recording' : stageLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              timer,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Stop and save when you are finished.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
