import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _companionBannedPatterns = <String, String>{
  r'AI friend': 'AI friend',
  r'\bcompanion\b': 'companion',
  r'\btherapist\b': 'therapist',
  r'\btherapy\b': 'therapy',
  r'\bdiagnosis\b': 'diagnosis',
  r'mental health': 'mental health',
  r'\bwellness\b': 'wellness',
  r'\bhealing\b': 'healing',
  r'\btrauma\b': 'trauma',
  r'\bcoach\b': 'coach',
  r'\bcoaching\b': 'coaching',
  r'\baffirmation\b': 'affirmation',
  r'inner child': 'inner child',
  r'emotional support': 'emotional support',
  r'chat with': 'chat with',
  r'\bchatbot\b': 'chatbot',
  r'\bchat\b': 'chat',
  r'\bjournal\b': 'journal',
  r'\brosebud\b': 'Rosebud',
  r'AI journal': 'AI journal',
};

const _bannedPatterns = <String, String>{
  r'\bVoiceMemory\b': 'VoiceMemory',
  r'Cloud processing': 'Cloud processing',
  r'Cloud sync unavailable': 'Cloud sync unavailable',
  r'Cloud analysis pending': 'Cloud analysis pending',
  r'Never synced': 'Never synced',
  r'archive intelligence': 'archive intelligence',
  r'\barchive\b': 'archive',
  r'\bbeliefs?\b': 'belief/beliefs',
  r'\bintelligence\b': 'intelligence',
  r'\bdiscover(?:y|ies)?\b': 'discover/discovery',
  r'\btheory\b': 'theory',
  r'\banalyst\b': 'analyst',
  r'\bhistorian\b': 'historian',
  r'\bsynthesis\b': 'synthesis',
  r'\blifecycle\b': 'lifecycle',
  r'\bidentity profile\b': 'identity profile',
  r'\bblind spot\b': 'blind spot',
  r'\bcontradiction\b': 'contradiction',
  r'\bprediction\b': 'prediction',
};

/// Internal QA sample reflections — natural language, not consumer UI copy.
const _excludedFromBannedWordScan = {
  'lib/features/first_session/first_pattern_quality_samples.dart',
};

/// Trial-only comprehension survey may use journal/chat labels.
const _companionCopyAllowedFiles = {
  'lib/features/trial/positioning_comprehension_model.dart',
  'lib/widgets/trial/positioning_comprehension_sheet.dart',
};

/// Consumer-visible copy sources (central + surfaces reachable from main tabs).
const _consumerCopyFiles = [
  'lib/product/consumer_ui_copy.dart',
  'lib/product/belief_product_copy.dart',
  'lib/config/screenshot_sample_data.dart',
  'lib/config/production_navigation.dart',
  'lib/config/release_config.dart',
  'lib/onboarding/onboarding_pages.dart',
  'lib/onboarding/onboarding_visuals.dart',
  'lib/billing/archive_paywall_copy.dart',
  'lib/billing/archive_paywall_plans.dart',
  'lib/billing/archive_intelligence_proof_copy.dart',
  'lib/billing/value_moment_paywall.dart',
  'lib/billing/archive_pro_feature_map.dart',
  'lib/billing/paywall_trigger_engine.dart',
  'lib/widgets/billing/pattern_memory_limit_card.dart',
  'lib/widgets/billing/pro_value_preview_card.dart',
  'lib/billing/pro_value_preview_model.dart',
  'lib/billing/pro_value_preview_engine.dart',
  'lib/widgets/archive/archive_range_selector.dart',
  'lib/widgets/patterns/archive_range_review_card.dart',
  'lib/billing/subscription_copy.dart',
  'lib/screens/subscription_review_preview.dart',
  'lib/screens/onboarding_screen.dart',
  'lib/screens/account_screen.dart',
  'lib/services/capture_save_messages.dart',
  'lib/widgets/patterns/patterns_empty_view.dart',
  'lib/design/warm_archive_copy.dart',
  'lib/design/empty_archive_experience.dart',
  'lib/features/insights/archive_insight_mapper.dart',
  'lib/features/archive_beliefs/archive_beliefs_presenter.dart',
  'lib/features/retention/archive_discovery_service.dart',
  'lib/features/return_reason/return_reason_coordinator.dart',
  'lib/widgets/processing_background_card.dart',
  'lib/widgets/first_archive_insight_section.dart',
  'lib/widgets/tomorrow_return/tomorrow_return_loop_card.dart',
  'lib/widgets/record/tomorrow_return_card.dart',
  'lib/widgets/record/today_noticed_post_save_card.dart',
  'lib/widgets/potential_signals_card.dart',
  'lib/widgets/patterns/patterns_come_back_tomorrow_card.dart',
  'lib/widgets/patterns/tomorrow_return_status_card.dart',
  'lib/widgets/record/tomorrow_commitment_card.dart',
  'lib/widgets/patterns/return_comparison_card.dart',
  'lib/widgets/patterns/trial_usefulness_prompt.dart',
  'lib/widgets/trial/trial_first_moment_card.dart',
  'lib/features/tomorrow_return/check_in_result_copy.dart',
  'lib/features/tomorrow_return/result_next_check_engine.dart',
  'lib/features/tomorrow_return/useful_result_takeaway_engine.dart',
  'lib/widgets/record/tomorrow_check_in_due_card.dart',
  'lib/widgets/record/check_in_completed_card.dart',
  'lib/widgets/record/result_next_check_card.dart',
  'lib/widgets/record/perspective_shift_card.dart',
  'lib/features/perspective/perspective_shift_engine.dart',
  'lib/widgets/record/kinder_angle_card.dart',
  'lib/features/perspective/kinder_angle_engine.dart',
  'lib/widgets/quick_help/quick_help_sheet.dart',
  'lib/widgets/quick_help/quick_help_button.dart',
  'lib/features/quick_help/quick_help_engine.dart',
  'lib/features/moments/key_moment_engine.dart',
  'lib/features/moments/moment_tag_model.dart',
  'lib/features/moments/moment_tag_engine.dart',
  'lib/screens/key_moments_screen.dart',
  'lib/screens/key_moment_detail_screen.dart',
  'lib/screens/ask_archive_screen.dart',
  'lib/widgets/patterns/archive_clean_view_card.dart',
  'lib/widgets/patterns/pattern_profile_card.dart',
  'lib/screens/pattern_profile_screen.dart',
  'lib/features/archive_clean/archive_clean_section_model.dart',
  'lib/features/archive_search/archive_search_model.dart',
  'lib/features/pattern_map/pattern_map_engine.dart',
  'lib/widgets/patterns/pattern_map_card.dart',
  'lib/screens/pattern_map_screen.dart',
  'lib/features/archive_memory/archive_memory_summary_engine.dart',
  'lib/features/archive_memory/memory_quality_model.dart',
  'lib/features/archive_memory/memory_quality_engine.dart',
  'lib/widgets/patterns/memory_quality_chip.dart',
  'lib/features/record/record_stack_policy.dart',
  'lib/features/retention/retention_state_engine.dart',
  'lib/features/retention/retention_diagnosis_engine.dart',
  'lib/widgets/retention/retention_state_card.dart',
  'lib/widgets/objective/current_objective_card.dart',
  'lib/features/objective/current_objective_engine.dart',
  'lib/features/objective/current_objective_widget_snapshot.dart',
  'lib/features/objective/current_objective_snapshot_builder.dart',
  'lib/features/objective/objective_shortcut_registry.dart',
  'lib/features/objective/current_objective_widget_exporter.dart',
  'lib/features/objective/current_objective_widget_bridge.dart',
  'lib/features/objective/current_objective_widget_refresh_service.dart',
  'docs/WIDGET_SHORTCUT_PREP.md',
  'docs/IOS_WIDGETKIT_SETUP.md',
  'docs/TODAYS_CHECK_WIDGET_QA.md',
  'lib/widgets/patterns/archive_memory_summary_card.dart',
  'lib/features/archive_memory/archive_evolution_engine.dart',
  'lib/widgets/patterns/archive_evolution_timeline_card.dart',
  'lib/screens/archive_evolution_timeline_screen.dart',
  'lib/features/monthly_review/monthly_pattern_review_engine.dart',
  'lib/widgets/patterns/monthly_pattern_review_card.dart',
  'lib/features/export/private_recap_model.dart',
  'lib/features/export/private_recap_engine.dart',
  'lib/widgets/export/private_recap_actions.dart',
  'lib/widgets/record/make_result_more_useful_sheet.dart',
  'lib/widgets/patterns/patterns_check_in_status_card.dart',
  'lib/widgets/patterns/missed_check_in_reason_prompt.dart',
  'lib/widgets/trial/check_in_worth_rating_prompt.dart',
  'lib/widgets/trial/check_in_result_rating_prompt.dart',
  'lib/widgets/patterns/return_streak_card.dart',
  'lib/widgets/patterns/change_summary_card.dart',
  'lib/widgets/patterns/weekly_pattern_recap_card.dart',
  'lib/widgets/record/watch_for_tomorrow_card.dart',
  'lib/widgets/record/todays_watch_for_card.dart',
  'lib/widgets/patterns/watch_for_result_card.dart',
  'lib/features/tomorrow_return/return_capture_engine.dart',
  'lib/features/tomorrow_return/watch_for_engine.dart',
  'lib/features/tomorrow_return/watch_for_prompt_engine.dart',
  'lib/features/tomorrow_return/watch_for_coordinator.dart',
  'lib/features/tomorrow_return/change_summary_engine.dart',
  'lib/features/tomorrow_return/weekly_pattern_recap_engine.dart',
  'lib/features/tomorrow_return/return_comparison_engine.dart',
  'lib/features/tomorrow_return/active_pattern_thread_engine.dart',
  'lib/features/tomorrow_return/active_pattern_thread_coordinator.dart',
  'lib/widgets/record/active_pattern_thread_prompt_card.dart',
  'lib/widgets/patterns/active_pattern_thread_card.dart',
  'lib/features/first_session/first_session_pattern_engine.dart',
  'lib/widgets/record/first_session_pattern_card.dart',
  'lib/widgets/record/post_save_insight_choice_card.dart',
  'lib/features/post_save_insight/post_save_insight_engine.dart',
  'lib/widgets/record/second_session_comparison_card.dart',
  'lib/features/retention/second_session_signal_engine.dart',
  'lib/features/activation/first_three_journey_engine.dart',
  'lib/widgets/activation/first_three_journey_card.dart',
  'lib/widgets/record/first_session_pattern_card.dart',
  'lib/widgets/record/post_save_insight_choice_card.dart',
  'lib/features/post_save_insight/post_save_insight_engine.dart',
  'lib/widgets/record/second_session_comparison_card.dart',
  'lib/features/retention/second_session_signal_engine.dart',
  'lib/features/tomorrow_return/check_in_reminder_service.dart',
  'lib/widgets/record/better_first_record_prompt_card.dart',
  'lib/widgets/record/pattern_memory_after_save_card.dart',
  'lib/widgets/patterns/pattern_memory_card.dart',
  'lib/widgets/record/pattern_progress_after_save_card.dart',
  'lib/widgets/patterns/pattern_progress_card.dart',
  'lib/features/pattern_memory/pattern_progress_engine.dart',
  'lib/widgets/record/pattern_next_action_card.dart',
  'lib/widgets/patterns/pattern_next_action_card.dart',
  'lib/features/pattern_memory/pattern_next_action_engine.dart',
  'lib/widgets/record/habit_proof_card.dart',
  'lib/widgets/patterns/habit_proof_card.dart',
  'lib/features/pattern_memory/habit_proof_engine.dart',
  'lib/widgets/record/weekly_pattern_recap_card.dart',
  'lib/widgets/patterns/weekly_recap_card.dart',
  'lib/features/pattern_memory/weekly_pattern_recap_engine.dart',
  'lib/widgets/patterns/pattern_share_recap_card.dart',
  'lib/features/pattern_memory/pattern_share_recap_engine.dart',
  'lib/widgets/record/first_loop_start_card.dart',
  'lib/widgets/record/first_loop_ready_card.dart',
  'lib/widgets/patterns/first_loop_state_card.dart',
  'lib/features/routine/routine_anchor_model.dart',
  'lib/widgets/routine/routine_anchor_chooser.dart',
  'lib/widgets/feedback/archive_feedback_chips.dart',
  'lib/features/archive_compression/archive_compression_engine.dart',
  'lib/widgets/patterns/archive_compression_card.dart',
  'lib/screens/archive_compression_screen.dart',
  'lib/widgets/onboarding/archive_memory_demo_card.dart',
  'lib/widgets/patterns/archive_memory_empty_preview_card.dart',
];

/// Fails if consumer copy still uses the old VoiceMemory brand name.
void main() {
  test('consumer_ui_copy uses ArchiveMe brand in string literals', () {
    final source = File('lib/product/consumer_ui_copy.dart').readAsStringSync();
    expect(source, isNot(contains("'VoiceMemory")));
    expect(source, contains('ArchiveMe'));
  });

  for (final path in _consumerCopyFiles) {
    if (_excludedFromBannedWordScan.contains(path)) continue;

    test('$path has no banned consumer jargon in string literals', () {
      final source = File(path).readAsStringSync();
      final violations = _scanBannedWords(source, path, _bannedPatterns);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('$path has no companion or therapy-style copy in string literals', () {
      if (_companionCopyAllowedFiles.contains(path)) return;
      final source = File(path).readAsStringSync();
      final violations = _scanBannedWords(
        source,
        path,
        _companionBannedPatterns,
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }
}

List<String> _scanBannedWords(
  String source,
  String path,
  Map<String, String> patterns,
) {
  final violations = <String>[];
  final literalPattern = RegExp(r"'([^']*)'");

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ')) continue;
    if (trimmed.startsWith('//')) continue;

    if (trimmed.contains(r'${')) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains('/')) continue;
      if (value.contains(r'${')) continue;
      if (value.startsWith('screenshot-') ||
          RegExp(r'^[bs]\d+$').hasMatch(value)) {
        continue;
      }
      if (value.startsWith('value_moment_') || value.startsWith('PAYWALL_')) {
        continue;
      }
      if (value.startsWith('contradiction:') ||
          value.startsWith('pattern-shift:') ||
          value.startsWith('pattern:') ||
          value.startsWith('theme:') ||
          value.startsWith('chapter:') ||
          value.startsWith('evo-') ||
          value.startsWith('blind-')) {
        continue;
      }
      if (const {
        'belief',
        'themes',
        'chapterIds',
        'count',
        'lastId',
      }.contains(value)) {
        continue;
      }
      if (_isInternalIdentifier(value)) continue;

      for (final entry in patterns.entries) {
        final re = RegExp(entry.key, caseSensitive: false);
        if (!re.hasMatch(value)) continue;

        if (entry.value == 'evidence' && _evidenceAllowed(value)) continue;
        if (entry.value == 'archive' && _archiveAllowed(value)) continue;
        if (entry.value == 'chat' && _chatAllowed(value)) continue;
        if (entry.value == 'journal' && _journalAllowed(value)) continue;

        violations.add('$path: banned "${entry.value}" in "$value"');
      }
    }
  }

  return violations;
}

bool _evidenceAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('based on') ||
      lower.contains('reflection') ||
      lower.contains('moment');
}

bool _archiveAllowed(String value) {
  if (value.contains('ArchiveMe')) return true;
  final lower = value.toLowerCase();
  if (lower.contains('archive timeline')) return true;
  if (lower.contains('archive review')) return true;
  if (lower.contains('ask my archive')) return true;
  if (lower.contains('your archive')) return true;
  if (lower.contains('clean up archive')) return true;
  if (lower == 'view archive') return true;
  if (lower == 'start my archive') return true;
  if (lower.contains('archive this signal')) return true;
  return false;
}

bool _chatAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('not a chat');
}

bool _journalAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('journals remember') || lower.contains('journaling');
}

bool _isInternalIdentifier(String value) {
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value);
}
