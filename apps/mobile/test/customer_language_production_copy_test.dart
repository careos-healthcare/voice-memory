import 'dart:io';

import 'package:archiveme_mobile/product/customer_language.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repo_file_scan.dart';

/// Release-reachable copy for focused beta (V1 tabs + marketing/legal surfaces).
const _productionCopyFiles = [
  'lib/features/archive_proof/visible_archive_proof_copy.dart',
  'lib/features/evidence_contract/evidence_eligibility_copy.dart',
  'lib/features/archive_theory/archive_theory_copy.dart',
  'lib/features/archive_v1/archive_v1_copy.dart',
  'lib/features/session_movement/session_movement_copy.dart',
  'lib/features/archive_home/evidence_ledger_copy.dart',
  'lib/widgets/archive_v1/insight_feed_copy.dart',
  'lib/features/support/support_feedback_copy.dart',
  'lib/features/submission/app_store_submission_copy.dart',
  'lib/onboarding/onboarding_pages.dart',
  'lib/features/trust/privacy_screen_copy.dart',
  'lib/features/trust/terms_screen_copy.dart',
  'lib/security/archive_privacy_controls_copy.dart',
  'lib/security/account_privacy_controls_copy.dart',
  'lib/features/archive_export/archive_export_pack_copy.dart',
  'lib/billing/subscription_billing_copy.dart',
  'lib/features/support/testflight_feedback_copy.dart',
  'lib/features/capture_flow/ui/capture_flow_panels.dart',
  'lib/record/record_screen_framing_copy.dart',
  '../../packages/shared/lib/site/web-marketing-copy.ts',
  '../../packages/shared/lib/trust-copy.ts',
  '../../packages/shared/lib/product/brand-copy.ts',
  '../../apps/web/app/page.tsx',
  '../../apps/web/app/contact/page.tsx',
  '../../apps/web/app/privacy/page.tsx',
];

/// Reviewed literals allowed to contain otherwise-banned substrings.
const _annotatedLiteralAllowlist = <String, String>{
  'ArchiveMe is not therapy, medical advice, or emergency support.':
      'Negative disclaimer — therapy/diagnosis in negation',
  'ArchiveMe resurfaces your own voice reflections. It is not therapy, counseling, medical advice, or a diagnosis.':
      'Web trust disclaimer',
  'Not a chat history. An evidence trail of what repeats.':
      'Evidence trail — not product "proof" claim',
  'Review evidence, not guesses': 'Store screenshot — evidence framing',
  'Share-safe summary': 'Renamed from proof — allowed',
  'Share safely': 'Action label without proof noun',
  'Free shows the first useful proof. Pro keeps the longer trail.':
      'Legacy paywall — tracked for paywall refresh',
  'Longer proof trail': 'Legacy paywall — tracked for paywall refresh',
  'Pro keeps the longer proof trail': 'Legacy paywall — tracked for paywall refresh',
  'customer_language.dart': 'Defines banned term list',
  'globalBannedPhrases': 'Privacy policy guard list',
  'bannedPrimaryUiTerms': 'Self-reference in glossary constants file',
};

bool _allowlistedLine(String path, String line) {
  if (line.trim().startsWith('import ')) return true;
  if (line.trim().startsWith('//')) return true;
  if (line.contains('package:archiveme_mobile')) return true;
  if (line.contains('@Deprecated')) return true;
  if (line.contains('bannedPrimaryUiTerms') ||
      line.contains('globalBannedPhrases') ||
      line.contains('PrivacyCopyPolicy')) {
    return true;
  }
  if (path.endsWith('consumer_ui_copy.dart') &&
      line.contains('paywallDifferentiation')) {
    return true;
  }
  return false;
}

bool _literalAllowlisted(String path, String value) {
  if (_annotatedLiteralAllowlist.containsKey(value)) return true;
  if (path.endsWith('customer_language.dart')) return true;
  final lower = value.toLowerCase();
  if (lower.contains('not therapy') ||
      lower.contains('not diagnos') ||
      lower.contains('not medical') ||
      lower.contains('not a chat') ||
      lower.contains('does not prove')) {
    return true;
  }
  if (lower.contains('prove it wrong') ||
      lower.contains('prove this wrong') ||
      lower.contains('could prove this wrong')) {
    return true;
  }
  if (lower.contains('chatgpt') &&
      lower.contains('not trying to answer better than')) {
    return true;
  }
  return false;
}

List<String> _scanBannedTerms(String path, String source) {
  final violations = <String>[];
  final literalPattern = RegExp("'([^']*)'");

  for (final line in source.split('\n')) {
    if (_allowlistedLine(path, line)) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains(r'${')) continue;
      if (_literalAllowlisted(path, value)) continue;

      final lower = value.toLowerCase();
      for (final banned in CustomerLanguage.bannedPrimaryUiTerms) {
        if (lower.contains(banned.toLowerCase())) {
          violations.add('$path: banned "$banned" in "$value"');
        }
      }

      if (lower.contains('hello@voicememory.app') ||
          lower.contains('careosapp.co.uk')) {
        violations.add('$path: legacy contact "$value"');
      }

      if (RegExp(r'\bproves?\b', caseSensitive: false).hasMatch(value) &&
          !lower.contains('prove it wrong') &&
          !lower.contains('proving-enough')) {
        violations.add('$path: certainty verb "prove(s)" in "$value"');
      }
    }
  }

  return violations;
}

void main() {
  test('customer language defines canonical feedback controls', () {
    expect(CustomerLanguage.feedbackCorrect, 'Correct');
    expect(CustomerLanguage.feedbackFits, 'Fits');
    expect(CustomerLanguage.feedbackPartlyFits, 'Partly fits');
    expect(CustomerLanguage.feedbackNotForMe, 'Not for me');
    expect(CustomerLanguage.feedbackHide, 'Hide');
    expect(CustomerLanguage.contactEmail, 'hello@archiveme.app');
  });

  test('evidence eligibility copy uses canonical pattern labels', () {
    final file = resolveRepoScanFile(
      'lib/features/evidence_contract/evidence_eligibility_copy.dart',
    );
    final source = file.readAsStringSync();
    expect(source, contains('Possible pattern'));
    expect(source, contains('Fits'));
    expect(source, contains('Partly fits'));
    expect(source, contains('Not for me'));
  });

  for (final path in _productionCopyFiles) {
    test('$path follows customer language policy', () {
      final file = resolveRepoScanFile(path);
      late final String source;
      try {
        source = file.readAsStringSync();
      } on FileSystemException {
        fail('missing $path (resolved ${file.path})');
      }
      final violations = _scanBannedTerms(path, source);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }
}
