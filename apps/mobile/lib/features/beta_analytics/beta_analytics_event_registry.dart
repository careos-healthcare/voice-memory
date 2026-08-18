/// Privacy-safe beta analytics contract for the focused beta.
///
/// North-star: **Useful Evidence Week** — user saves ≥2 moments in a calendar
/// week and views a possible pattern/change they mark Fits, Partly fits, or
/// Corrected. Derived in [BetaAnalyticsRetentionDeriver], not a client event.
abstract final class BetaAnalyticsEventRegistry {
  BetaAnalyticsEventRegistry._();

  static const String schemaVersion = 'beta_analytics_v1';

  /// All events permitted on the production analytics graph.
  static final Set<String> productionEventNames = {
    for (final def in all) def.name,
  };

  static const List<BetaAnalyticsEventDefinition> all = [
    ...activationFunnel,
    ...trustReliability,
    ...derivedRetention,
  ];

  static const List<BetaAnalyticsEventDefinition> activationFunnel = [
    BetaAnalyticsEventDefinition(
      name: 'onboarding_viewed',
      owner: 'activation',
      purpose: 'Activation funnel — first exposure to onboarding.',
      trigger: 'OnboardingScreen mounts.',
      allowedPayloadKeys: const {'surface'},
      enumConstraints: const {
        'surface': {'onboarding'},
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Dropped with anonymous install cohort; no content.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'capture_intent_selected',
      owner: 'activation',
      purpose: 'Activation funnel — voice vs typed capture intent.',
      trigger: 'Customer selects voice or typed input before capture.',
      allowedPayloadKeys: const {'intent'},
      enumConstraints: const {
        'intent': {'voice', 'typed'},
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Dropped with anonymous install cohort; no content.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'first_moment_saved_local',
      owner: 'activation',
      purpose: 'Activation funnel — first durable encrypted/local save.',
      trigger: 'JournalStore._writeAll completes for first active moment.',
      allowedPayloadKeys: const {'capture_kind'},
      enumConstraints: const {
        'capture_kind': {'voice', 'typed', 'typed_attach'},
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only; timestamp used locally for windows.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'archive_first_viewed',
      owner: 'activation',
      purpose: 'Activation funnel — first Archive tab visit.',
      trigger: 'ArchiveBeliefScreen mounts for the first time.',
      allowedPayloadKeys: const {'surface'},
      enumConstraints: const {
        'surface': {'archive'},
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Dropped with anonymous install cohort; no content.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'second_moment_saved_72h',
      owner: 'activation',
      purpose: 'Recurrence — second durable save within 72h of first.',
      trigger: 'JournalStore._writeAll completes for second active moment.',
      allowedPayloadKeys: const {'within_window'},
      enumConstraints: const {
        'within_window': {'true', 'false'},
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'third_moment_saved_7d',
      owner: 'activation',
      purpose:
          'Evidence policy gate — third durable save (possible pattern minimum).',
      trigger: 'JournalStore._writeAll completes for third active moment.',
      allowedPayloadKeys: const {'within_window'},
      enumConstraints: const {
        'within_window': {'true', 'false'},
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'possible_pattern_eligible',
      owner: 'evidence',
      purpose:
          'Possible pattern threshold met per EvidenceEligibilityPolicyConfig.',
      trigger:
          'Third durable save completes OR eligibility re-evaluated at 3+ moments.',
      allowedPayloadKeys: const {'policy_version'},
      enumConstraints: const {},
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'possible_pattern_viewed',
      owner: 'evidence',
      purpose: 'Customer saw a possible pattern/change surface.',
      trigger: 'Verified pattern card or Changes section renders eligible claim.',
      allowedPayloadKeys: const {'surface'},
      enumConstraints: const {
        'surface': {
          'archive_changes',
          'post_save',
          'changes_tab',
          'record',
        },
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'evidence_opened',
      owner: 'evidence',
      purpose: 'Customer opened an evidence trail for a pattern/change.',
      trigger: 'BeliefEvidenceScreen loads with eligible evidence.',
      allowedPayloadKeys: const {'surface'},
      enumConstraints: const {
        'surface': {'belief_evidence', 'entry_detail', 'export_preview'},
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized counts only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'pattern_reviewed',
      owner: 'evidence',
      purpose: 'Customer validated or rejected a possible pattern/change.',
      trigger: 'ArchiveCorrectionStore persists correction after durable write.',
      allowedPayloadKeys: const {'review_outcome'},
      enumConstraints: const {
        'review_outcome': {
          'fits',
          'partly_fits',
          'not_for_me',
          'corrected',
          'hidden',
        },
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Anonymized outcome enum only; no correction text.',
      oncePerInstall: false,
    ),
  ];

  static const List<BetaAnalyticsEventDefinition> trustReliability = [
    BetaAnalyticsEventDefinition(
      name: 'consent_decision',
      owner: 'trust',
      purpose: 'Remote processing consent by purpose — never content.',
      trigger: 'Onboarding consent step or settings consent change persists.',
      allowedPayloadKeys: const {'purpose', 'decision'},
      enumConstraints: const {
        'purpose': {'remote_transcription', 'remote_reflection'},
        'decision': {'grant', 'decline', 'revoke'},
      },
      retention: Duration(days: 365),
      deletionBehavior: 'Purpose + decision enum only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'prohibited_remote_attempt_after_decline',
      owner: 'trust',
      purpose:
          'Monitoring — remote I/O attempted without active consent (should be impossible).',
      trigger: 'Audit hook before remote network I/O when consent is not granted.',
      allowedPayloadKeys: const {'purpose'},
      enumConstraints: const {
        'purpose': {'remote_transcription', 'remote_reflection'},
      },
      retention: Duration(days: 30),
      deletionBehavior: 'Alert event; no content.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'local_save_result',
      owner: 'trust',
      purpose: 'Local durability outcome with coarse latency bucket.',
      trigger: 'Capture flow after awaited local persist attempt completes.',
      allowedPayloadKeys: const {'result', 'capture_kind', 'latency_bucket'},
      enumConstraints: const {
        'result': {'success', 'failure'},
        'capture_kind': {'voice', 'typed', 'typed_attach'},
        'latency_bucket': BetaAnalyticsLatencyBuckets.all,
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Structural enums only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'remote_processing_result',
      owner: 'trust',
      purpose: 'Remote processing outcome with coarse latency bucket.',
      trigger: 'Capture pipeline remote stage completes or is skipped.',
      allowedPayloadKeys: const {'result', 'kind', 'latency_bucket'},
      enumConstraints: const {
        'result': {'success', 'failure', 'skipped'},
        'kind': {'voice', 'typed', 'typed_attach', 'retry'},
        'latency_bucket': BetaAnalyticsLatencyBuckets.all,
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Structural enums only; no provider errors.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'export_result',
      owner: 'trust',
      purpose: 'Export flow outcome.',
      trigger: 'ExportScreen share completes or fails.',
      allowedPayloadKeys: const {'result'},
      enumConstraints: const {
        'result': {'success', 'failure'},
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Success/failure enum only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'deletion_result',
      owner: 'trust',
      purpose: 'Deletion flow outcome.',
      trigger: 'ArchiveDataDeletionService or account deletion completes.',
      allowedPayloadKeys: const {'result', 'scope'},
      enumConstraints: const {
        'result': {'success', 'failure'},
        'scope': {'local_archive', 'account'},
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Structural enums only.',
      oncePerInstall: false,
    ),
    BetaAnalyticsEventDefinition(
      name: 'app_recovery_result',
      owner: 'trust',
      purpose: 'Pending capture recovery outcome.',
      trigger: 'CaptureFlowController recovery attempt completes.',
      allowedPayloadKeys: const {'result', 'reason_bucket'},
      enumConstraints: const {
        'result': {'success', 'failure', 'none'},
        'reason_bucket': {
          'pending_audio',
          'permission',
          'storage',
          'unknown',
        },
      },
      retention: Duration(days: 90),
      deletionBehavior: 'Structural enums only.',
      oncePerInstall: false,
    ),
  ];

  /// Derived locally — not misleading optimistic client emits.
  static const List<BetaAnalyticsEventDefinition> derivedRetention = [
    BetaAnalyticsEventDefinition(
      name: 'retained_capture_d7',
      owner: 'retention',
      purpose:
          'Derived retention — second+ capture on or after day 7 from first save.',
      trigger:
          'BetaAnalyticsRetentionDeriver evaluates local save timestamps.',
      allowedPayloadKeys: const {'cohort_day'},
      enumConstraints: const {},
      retention: Duration(days: 365),
      deletionBehavior: 'Derived aggregate; emitted once when criterion met.',
      oncePerInstall: true,
    ),
    BetaAnalyticsEventDefinition(
      name: 'retained_capture_d30',
      owner: 'retention',
      purpose:
          'Derived retention — second+ capture on or after day 30 from first save.',
      trigger:
          'BetaAnalyticsRetentionDeriver evaluates local save timestamps.',
      allowedPayloadKeys: const {'cohort_day'},
      enumConstraints: const {},
      retention: Duration(days: 365),
      deletionBehavior: 'Derived aggregate; emitted once when criterion met.',
      oncePerInstall: true,
    ),
  ];

  static BetaAnalyticsEventDefinition? definitionFor(String name) {
    final normalized = name.trim().toLowerCase();
    for (final def in all) {
      if (def.name == normalized) return def;
    }
    return null;
  }

  static bool isProductionEvent(String name) =>
      productionEventNames.contains(name.trim().toLowerCase());
}

/// Coarse latency buckets — never raw durations or timestamps in payloads.
abstract final class BetaAnalyticsLatencyBuckets {
  BetaAnalyticsLatencyBuckets._();

  static const sub500ms = 'sub_500ms';
  static const ms500To2s = 'ms_500_2s';
  static const s2To5 = 's_2_5';
  static const s5Plus = 's_5_plus';
  static const unknown = 'unknown';

  static const Set<String> all = {
    sub500ms,
    ms500To2s,
    s2To5,
    s5Plus,
    unknown,
  };

  static String bucketFor(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms < 500) return sub500ms;
    if (ms < 2000) return ms500To2s;
    if (ms < 5000) return s2To5;
    return s5Plus;
  }
}

class BetaAnalyticsEventDefinition {
  const BetaAnalyticsEventDefinition({
    required this.name,
    required this.owner,
    required this.purpose,
    required this.trigger,
    required this.allowedPayloadKeys,
    required this.enumConstraints,
    required this.retention,
    required this.deletionBehavior,
    required this.oncePerInstall,
  });

  final String name;
  final String owner;
  final String purpose;
  final String trigger;
  final Set<String> allowedPayloadKeys;
  final Map<String, Set<String>> enumConstraints;
  final Duration retention;
  final String deletionBehavior;
  final bool oncePerInstall;
}

/// Identity boundary for beta analytics.
///
/// - **Anonymous / local phase:** Firebase receives only registry events with
///   structural enums. No account id, email, or device-stable id is attached
///   by this module. Milestone timestamps live in [MobilePrefsStore] only.
/// - **Account-linked phase:** Begins only if the customer signs in AND a
///   future product decision explicitly enables account-scoped analytics.
///   Focused beta ships with anonymous Firebase events only; server-side
///   cohort joins use install-date buckets, not journal content.
/// - **Consent boundary:** [consent_decision] tracks remote *processing*
///   purposes only. Declining remote transcription/reflection does not block
///   local beta analytics emission and never itself triggers a remote analytics
///   upload — [BetaAnalyticsTracker] writes locally first, then optionally
///   forwards structural events to Firebase when collection is enabled.
abstract final class BetaAnalyticsIdentityPolicy {
  BetaAnalyticsIdentityPolicy._();

  static const String phase = 'anonymous_local_v1';
}
