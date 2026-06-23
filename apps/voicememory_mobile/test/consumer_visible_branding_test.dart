import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scans likely user-facing Dart sources for forbidden consumer branding.
///
/// Internal-only matches (theme class names, package imports, bundle ids) are
/// allowlisted below — they must never be rendered as UI copy.
const _consumerFacingSources = [
  'lib/product/consumer_ui_copy.dart',
  'lib/product/loop_mode_copy.dart',
  'lib/product/loop_acquisition_copy.dart',
  'lib/product/testflight_invite_copy.dart',
  'lib/product/acquisition_start_copy.dart',
  'lib/billing/archive_paywall_copy.dart',
  'lib/billing/subscription_copy.dart',
  'lib/billing/archive_paywall_plans.dart',
  'lib/onboarding/onboarding_pages.dart',
  'lib/onboarding/onboarding_visuals.dart',
  'lib/screens/onboarding_screen.dart',
  'lib/screens/onboarding_intent_screen.dart',
  'lib/screens/onboarding_loop_screen.dart',
  'lib/screens/account_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/about_screen.dart',
  'lib/screens/privacy_screen.dart',
  'lib/features/trust/privacy_screen_copy.dart',
  'lib/features/trust/terms_screen_copy.dart',
  'lib/features/trust/pro_trust_copy.dart',
  'lib/features/archive_proof/visible_archive_proof_copy.dart',
  'lib/screens/paywall_screen.dart',
  'lib/screens/export_screen.dart',
  'lib/security/archive_privacy_controls_copy.dart',
  'lib/security/privacy_data_controls_copy.dart',
  'lib/features/archive_export/archive_export_pack_copy.dart',
  'lib/features/demo/sample_archive_copy.dart',
  'lib/features/help/help_reviewer_guide_copy.dart',
  'lib/features/submission/app_store_submission_copy.dart',
  'lib/features/return_ritual/return_ritual_copy.dart',
  'lib/features/moment_quality/moment_quality_copy.dart',
  'lib/features/pro/pro_value_preview_copy.dart',
  'lib/features/return_changes/archive_return_changes_copy.dart',
  'lib/features/support/support_feedback_copy.dart',
  'lib/widgets/security/archive_privacy_controls_card.dart',
  'lib/widgets/security/archive_data_flow_sheet.dart',
  'lib/security/account_privacy_controls_copy.dart',
  'lib/security/privacy_copy_policy.dart',
  'lib/widgets/account/account_privacy_controls_section.dart',
  'lib/record/record_screen_framing_copy.dart',
  'lib/widgets/record/record_first_run_privacy_reassurance.dart',
  'lib/screens/record_screen.dart',
  'lib/features/record/daily_mirror_copy.dart',
  'lib/widgets/record/daily_mirror_record_card.dart',
  'lib/widgets/record/first_recording_handoff_card.dart',
  'lib/widgets/record/loop_mode_first_handoff_card.dart',
  'lib/widgets/record/today_noticed_post_save_card.dart',
  'lib/widgets/record/post_save_recorded_summary_card.dart',
  'lib/features/post_save/post_save_recorded_summary_copy.dart',
  'lib/widgets/loop_mode/loop_paywall_teaser_card.dart',
  'lib/widgets/retention/reminder_pre_prompt_sheet.dart',
  'lib/services/capture_save_messages.dart',
  'lib/api/api_error_message.dart',
  'ios/Runner/Info.plist',
];

const _forbiddenPatterns = <String, String>{
  r'\bVoiceMemory\b': 'VoiceMemory',
  r'\bvoice memory\b': 'voice memory',
  r'\bVoice Memory\b': 'Voice Memory',
  r'\bChatGPT\b': 'ChatGPT',
  r'\bOpenAI processing\b': 'OpenAI processing',
  r'\bWhisper\b': 'Whisper',
};

/// Lines that may mention legacy identifiers but are not rendered to users.
bool _allowlistedLine(String path, String line) {
  if (line.trim().startsWith('import ')) return true;
  if (line.trim().startsWith('//')) return true;
  if (line.contains('package:voicememory_mobile')) return true;
  if (line.contains('VoiceMemoryTypography')) return true;
  if (line.contains('VoiceMemoryColors')) return true;
  if (line.contains('VoiceMemoryCards')) return true;
  if (line.contains('VoiceMemorySearch')) return true;
  if (line.contains('voicememory_typography')) return true;
  if (line.contains('voicememory_cards')) return true;
  if (line.contains('voicememory_colors')) return true;
  if (line.contains('voice-memory-iota')) return true;
  if (line.contains('voicememory.app')) return true;
  if (line.contains('voice_capture') ||
      line.contains('offline_voice_capture')) {
    return true;
  }
  if (line.contains('@Deprecated') || line.contains('@deprecated')) return true;
  if (line.contains('voiceMemoryNoticed')) return true;
  if (line.contains('bannedTerms') ||
      line.contains('bannedInternalTerms') ||
      line.contains('bannedFirstImpressionPhrases')) {
    return true;
  }
  if (path.endsWith('Info.plist') && line.contains('voicememory')) {
    // URL scheme / bundle id — not consumer copy.
    return line.contains('CFBundleURLSchemes') ||
        line.contains('PRODUCT_BUNDLE_IDENTIFIER') ||
        line.contains('<string>voicememory</string>');
  }
  return false;
}

List<String> _scanFile(String path) {
  final source = File(path).readAsStringSync();
  final violations = <String>[];
  final literalPattern = RegExp(r"'([^']*)'");

  for (final line in source.split('\n')) {
    if (_allowlistedLine(path, line)) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains(r'${')) continue;

      for (final entry in _forbiddenPatterns.entries) {
        if (RegExp(entry.key, caseSensitive: false).hasMatch(value)) {
          violations.add('$path: forbidden "${entry.value}" in "$value"');
        }
      }
    }
  }

  return violations;
}

void main() {
  test('iOS display name is ArchiveMe', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>CFBundleDisplayName</key>'));
    expect(plist, contains('<string>ArchiveMe</string>'));
  });

  for (final path in _consumerFacingSources) {
    test('$path has no consumer-visible VoiceMemory branding', () {
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
      final violations = _scanFile(path);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }
}
