import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Banned in consumer-facing UI copy (case-insensitive substring match).
const _bannedConsumerStrings = [
  'ChatGPT',
  'VoiceMemory',
  'voicememory',
  'voice memory',
  'OpenAI processing',
  'powered by ChatGPT',
  'OpenAI memory',
  'train OpenAI',
  'train our models',
  'Whisper',
  'wrapper',
];

/// Internal-only occurrences documented here — not rendered as product copy.
const _internalAllowlistReasons = <String, String>{
  'package:archiveme_mobile': 'Dart package import path',
  'VoiceMemoryColors': 'Internal theme token class',
  'VoiceMemoryCards': 'Internal card style class',
  'VoiceMemoryTypography': 'Internal typography class',
  'VoiceMemorySearch': 'Internal search helper class',
  'voicememory_typography.dart': 'Internal theme file import',
  'voicememory_cards.dart': 'Internal theme file import',
  'voicememory_colors.dart': 'Internal theme file import',
  'hello@archiveme.app': 'Primary customer contact email',
  'support@archiveme.app': 'Billing alias — same inbox via DNS forward',
  'archiveme.app': 'Canonical marketing host',
  'voicememory.app': 'Legacy marketing host — redirects to archiveme.app',
  'com.voicememory': 'Bundle / package identifier',
  'VOICE_MEMORY_SCREENSHOT_MODE': 'Build flag — not user-visible',
  'ENABLE_GPT5_ARCHIVE_SYNTHESIS': 'Build flag — not user-visible',
};

const _mobileConsumerCopyFiles = [
  'lib/product/consumer_ui_copy.dart',
  'lib/product/loop_mode_copy.dart',
  'lib/product/loop_acquisition_copy.dart',
  'lib/product/testflight_invite_copy.dart',
  'lib/product/acquisition_start_copy.dart',
  'lib/features/trust/privacy_screen_copy.dart',
  'lib/features/trust/pro_trust_copy.dart',
  'lib/billing/archive_paywall_copy.dart',
  'lib/billing/subscription_copy.dart',
  'lib/billing/archive_paywall_plans.dart',
  'lib/billing/value_moment_paywall.dart',
  'lib/onboarding/onboarding_pages.dart',
  'lib/onboarding/onboarding_visuals.dart',
  'lib/features/onboarding/screens/onboarding_screen.dart',
  '../../packages/archiveme_research/lib/screens/onboarding_intent_screen.dart',
  '../../packages/archiveme_research/lib/screens/onboarding_loop_screen.dart',
  'lib/features/auth/screens/account_screen.dart',
  'lib/features/settings/screens/settings_screen.dart',
  'lib/features/settings/screens/about_screen.dart',
  'lib/features/settings/screens/privacy_screen.dart',
  'lib/widgets/scaffold_shell.dart',
  'lib/widgets/pushed_screen_shell.dart',
  'lib/billing/screens/paywall_screen.dart',
  'lib/features/settings/screens/export_screen.dart',
  'lib/services/capture_save_messages.dart',
  'lib/api/api_error_message.dart',
  'lib/config/creator_demo_mode.dart',
  'lib/config/screenshot_sample_data.dart',
  'ios/Runner/Info.plist',
  'android/app/src/main/res/values/strings.xml',
];

bool _isAllowlistedLine(String path, String line) {
  if (line.trim().startsWith('import ')) return true;
  if (line.trim().startsWith('//')) return true;
  for (final entry in _internalAllowlistReasons.entries) {
    if (line.contains(entry.key)) return true;
  }
  if (path.endsWith('Info.plist') && line.contains('voicememory')) {
    return line.contains('CFBundleURLSchemes') ||
        line.contains('PRODUCT_BUNDLE_IDENTIFIER') ||
        line.contains('<string>voicememory</string>');
  }
  if (path.endsWith('consumer_ui_copy.dart') &&
      line.contains('paywallDifferentiation')) {
    return true;
  }
  return false;
}

List<String> _scanStringLiterals(String path, String source) {
  final violations = <String>[];
  final literalPattern = RegExp("'([^']*)'");

  for (final line in source.split('\n')) {
    if (_isAllowlistedLine(path, line)) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains(r'${')) continue;
      final lower = value.toLowerCase();
      for (final banned in _bannedConsumerStrings) {
        if (lower.contains(banned.toLowerCase())) {
          violations.add('$path: banned "$banned" in "$value"');
        }
      }
    }
  }

  return violations;
}

void main() {
  group('Consumer brand exposure audit', () {
    test('internal allowlist is documented', () {
      expect(_internalAllowlistReasons.length, greaterThan(5));
      expect(
        _internalAllowlistReasons.containsKey('VoiceMemoryColors'),
        isTrue,
      );
    });

    for (final path in _mobileConsumerCopyFiles) {
      test('$path avoids banned consumer brand/provider strings', () {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
        final violations = _scanStringLiterals(
          path,
          File(path).readAsStringSync(),
        );
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    }

    // This used to require the literal phrase "ai transcription and analysis",
    // which `globalBannedPhrases` forbids via `\bai\b` — the two could not both
    // be satisfied. The ban wins. "AI" names a category, not a mechanism, and
    // it is exactly the word that lets a privacy section sound like a
    // disclosure without being one; "cloud" says where the work happens, which
    // is the fact a reader on this screen is looking for.
    //
    // The assertion is rewritten to check the thing the old name claimed to
    // check — that the section is transparent — which now means naming the
    // companies rather than containing a particular adjective.
    test('privacy copy discloses transcription and analysis transparently', () {
      final copy = PrivacyScreenCopy.all.join(' ').toLowerCase();
      expect(copy, contains('cloud transcription and analysis'));
      expect(copy, contains('transcribe'));
      expect(copy, contains('processing providers'));
      expect(copy, contains('openai'));
      expect(copy, contains('google'));
      expect(copy, isNot(contains('chatgpt')));
      // A vendor name belongs in the disclosure, not in a section heading.
      expect(copy, isNot(contains('openai processing')));
      // Anthropic is not called anywhere in this repository, and naming a
      // vendor to deny it invites the question about the ones in use.
      expect(copy, isNot(contains('anthropic')));
    });

    test('central product copy uses ArchiveMe', () {
      expect(AppConfig.appName, 'ArchiveMe');
      expect(
        ConsumerUiCopy.paywallHeadline.toLowerCase(),
        isNot(contains('voicememory')),
      );
    });

    test('paywall/trust/onboarding strings avoid VoiceMemory and ChatGPT', () {
      final bundle = [
        ConsumerUiCopy.paywallHeadline,
        ConsumerUiCopy.onboardingPositioningHeadline,
        ...ProTrustCopy.all,
      ].join(' ').toLowerCase();
      expect(bundle, isNot(contains('voicememory')));
      expect(bundle, isNot(contains('voice memory')));
      expect(bundle, isNot(contains('chatgpt')));
    });

    test(
      'analytics event names unchanged and contain no VoiceMemory branding',
      () {
        const expectedEvents = {
          ActivationFunnelAnalytics.firstRecordingSaved,
          ActivationFunnelAnalytics.paywallSeen,
          ActivationFunnelAnalytics.purchaseCompleted,
        };
        for (final event in expectedEvents) {
          expect(event.toLowerCase(), isNot(contains('voicememory')));
          expect(event.toLowerCase(), isNot(contains('chatgpt')));
        }
      },
    );
  });
}