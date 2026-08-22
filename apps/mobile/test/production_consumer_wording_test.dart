import 'dart:io';

import 'package:archiveme_mobile/features/onboarding/first_60_second_state.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Internal vocabulary that must not appear in production-facing copy.
const _bannedInternalPhrases = [
  'Why Pro exists',
  'TestFlight',
  'RevenueCat',
  'entitlements',
  'server entitlements',
  'Feature locked',
  'Upgrade required',
  'Billing entitlement',
  'billing entitlement',
  'launch readiness',
  'vercel.app',
];

/// Compile-time consumer copy only — not screens with imports or runtime UI.
const _productionCopyFiles = [
  'lib/product/consumer_ui_copy.dart',
  'lib/product/loop_mode_copy.dart',
  'lib/features/trust/pro_trust_copy.dart',
  'lib/features/trust/terms_screen_copy.dart',
  'lib/features/onboarding/first_user_experience_copy.dart',
  'lib/features/onboarding/first_60_second_state.dart',
  'lib/features/onboarding/record_return_pro_state.dart',
  'lib/billing/archive_paywall_copy.dart',
  'lib/billing/paywall_source.dart',
  'lib/billing/pro_value_preview_engine.dart',
  'lib/billing/value_moment_paywall_trigger.dart',
  'lib/features/pressure_retention/start_here_save_receipt_model.dart',
  'lib/features/archive_growth/archive_growth_copy.dart',
  'lib/features/archive_evidence/archive_belief_thread_copy.dart',
];

bool _isAllowlistedLine(String line) {
  if (line.trim().startsWith('import ')) return true;
  if (line.trim().startsWith('//')) return true;
  if (line.contains('syncNotAvailableTestFlight')) return true;
  return false;
}

List<String> _stringLiteralViolations(String path, String source) {
  final violations = <String>[];
  final literalPattern = RegExp("'([^']*)'");

  for (final line in source.split('\n')) {
    if (_isAllowlistedLine(line)) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains(r'$')) continue;
      for (final banned in _bannedInternalPhrases) {
        if (value.toLowerCase().contains(banned.toLowerCase())) {
          violations.add('$path: "$value" contains "$banned"');
        }
      }
    }
  }

  return violations;
}

void main() {
  group('production consumer wording', () {
    for (final path in _productionCopyFiles) {
      test('$path avoids internal product vocabulary', () {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
        final violations = _stringLiteralViolations(
          path,
          File(path).readAsStringSync(),
        );
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    }

    test('Pro bridge titles use continuity framing', () {
      expect(
        ProTrustCopy.proTitle,
        'Keep the longer proof trail',
      );
      expect(
        First60Copy.proTitle,
        'Keep the longer proof trail',
      );
      expect(
        RecordReturnProCopy.proTitle,
        'Keep the longer proof trail.',
      );
    });

    test('paywall headline uses continuity framing', () {
      expect(
        ConsumerUiCopy.paywallHeadline,
        'You saw the first useful repeat.',
      );
      expect(
        ConsumerUiCopy.paywallSubhead,
        'Free shows the first useful proof. Pro keeps the longer trail.',
      );
      expect(
        ConsumerUiCopy.paywallSetupUnavailableBody,
        isNot(contains('TestFlight')),
      );
    });

    test('Pro bridge gates wait until repeat value', () {
      expect(
        First60Gates.showProBridge(
          entryCount: 1,
          resolved: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        First60Gates.showProBridge(
          entryCount: 2,
          resolved: false,
          hasArchiveProof: false,
        ),
        isFalse,
      );
      expect(
        First60Gates.showProBridge(
          entryCount: 2,
          resolved: false,
          hasArchiveProof: true,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isTrue,
      );
    });
  });
}