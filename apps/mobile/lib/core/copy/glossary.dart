/// Canonical product words for V1 display copy.
///
/// Routes and storage keys keep their existing names. Only strings a person
/// can read should use these terms.
abstract final class Glossary {
  Glossary._();

  static const entry = 'Entry';
  static const pattern = 'Pattern';
  static const evidence = 'Evidence';
  static const archive = 'Archive';
  static const recordCta = 'Record';

  static const definitions = <String, String>{
    entry: 'a saved recording or text',
    pattern: 'something that repeats',
    evidence: 'quoted original words',
    archive: 'everything',
  };

  /// Other product words, and the canonical term they fold into.
  static const synonymOf = <String, String>{
    'moment': entry,
    'save': entry,
    'check': pattern,
    'thread': pattern,
    'belief': pattern,
    'pressure loop': pattern,
    'proof': evidence,
    'capacity': archive,
  };

  /// Whole words that must not appear in V1-visible display strings.
  static const bannedSynonyms = <String>[
    'moment',
    'save',
    'check',
    'thread',
    'proof',
    'belief',
    'pressure loop',
    'capacity',
  ];

  /// Counts of those words in V1-route display literals before this rewrite.
  ///
  /// Scope: allowlisted route copy (V1RouteRegistry screens and the copy
  /// files they render), quarantined paths excluded.
  static const inventoryBeforeRewrite = <String, int>{
    'moment': 264,
    'save': 31,
    'entry': 8,
    'check': 24,
    'thread': 13,
    'pattern': 109,
    'proof': 2,
    'evidence': 111,
    'belief': 1,
    'pressure loop': 1,
    'capacity': 1,
    'archive': 112,
  };

  /// Dart sources whose string literals are V1-visible.
  static const v1VisibleCopyFiles = <String>[
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
    'lib/product/customer_language.dart',
    'lib/product/consumer_ui_copy.dart',
    'lib/features/onboarding/ui/onboarding_v1_copy.dart',
    'lib/features/onboarding/first_session_evidence_copy.dart',
  ];
}
