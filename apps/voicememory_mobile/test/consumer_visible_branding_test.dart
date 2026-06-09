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
  'lib/screens/paywall_screen.dart',
  'lib/screens/export_screen.dart',
  'lib/screens/record_screen.dart',
  'lib/widgets/record/first_recording_handoff_card.dart',
  'lib/widgets/record/loop_mode_first_handoff_card.dart',
  'lib/widgets/record/today_noticed_post_save_card.dart',
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
  if (line.contains('voice_capture') || line.contains('offline_voice_capture')) {
    return true;
  }
  if (line.contains('@Deprecated') || line.contains('@deprecated')) return true;
  if (line.contains('voiceMemoryNoticed')) return true;
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
