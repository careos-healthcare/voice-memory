import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/router/v1_route_inventory.dart';

/// Machine-readable V1 production contract — routes, modules, startup, and
/// launch capabilities. Validators in `tool/validate_v1_production_graph.sh`
/// and `test/v1_production_allowlist_test.dart` enforce this file.
abstract final class V1ProductionAllowlist {
  V1ProductionAllowlist._();

  /// Only these user-facing capabilities ship in the focused V1 release.
  static const launchCapabilities = [
    'voice_capture',
    'text_capture',
    'private_archive',
    'original_transcripts',
    'archive_search',
    'cautious_verified_patterns',
    'exact_evidence',
    'corrections_and_suppression',
    'account_security_settings',
    'export_and_deletion',
    'free_beta_unlimited_local_archive',
  ];

  /// Ordered startup phases — optional work must not block earlier phases.
  static const startupPhases = [
    V1StartupPhase(
      id: 'privacy_safe_shell',
      description: 'Theme, router shell, consent gates — no raw exceptions',
    ),
    V1StartupPhase(
      id: 'essential_local_archive',
      description: 'Journal store, prefs, device id — account namespace only',
    ),
    V1StartupPhase(
      id: 'v1_navigation',
      description: 'Record / Archive / Account tabs',
    ),
    V1StartupPhase(
      id: 'optional_async_services',
      description: 'Billing, sync, vault recovery — best-effort background',
    ),
  ];

  /// Screen widgets permitted as GoRoute builders when [enableV1Only] is true.
  static const productionRouterScreens = {
    'OnboardingScreen',
    'CaptureScreenHost',
    'CaptureScreen',
    'ArchiveBeliefScreen',
    'BeliefChangesScreen',
    'AccountScreen',
    'SecuritySettingsScreen',
    'AccountAuthScreen',
    'GuestDataMigrationScreen',
    'BeliefEvidenceScreen',
    'ArchiveEvidenceContextScreen',
    'EntryDetailScreen',
    'BeliefsScreen',
    'CaregiverAccessScreen',
    'BeliefDetailScreen',
    'SampleArchiveContextScreen',
    'DeleteAccountScreen',
    'SettingsScreen',
    'ExportScreen',
    'SupportFeedbackScreen',
    'AboutScreen',
    'PrivacyTrustCentreScreen',
    'PrivacyScreen',
    'TermsScreen',
    'MainShell',
    'OfflineSyncVerificationScreen',
  };

  /// Deferred screens that must never appear as production route builders.
  static const blockedProductionScreens = {
    'RecordScreen',
    'QuickTextCaptureScreen',
    'CapacityLoopScreen',
    'BetaFeedbackScreen',
    'JournalScreen',
    'PatternMapScreen',
    'DeveloperDiagnosticsScreen',
    'WeeklyArchiveReviewScreen',
    'TestingArchiveMeScreen',
    'YesterdaysSnapshotScreen',
    'ArchiveAnalystScreen',
    'MomentsScreen',
  };

  /// Packages that must not appear in production `lib/` imports.
  static const blockedProductionPackages = {
    'archiveme_research',
    'flutter_local_notifications',
  };

  /// Deep-link hosts/actions that must redirect safely in V1.
  static const deepLinkFallbacks = {
    'voice-session': '/record',
    'quick-capture': '/quick-capture',
  };

  static int get allowlistedRouteCount =>
      V1RouteInventory.v1AllowlistedRouteCount;

  static bool get v1OnlyEnabled => V1FeatureFlags.enableV1Only;

  static bool get storeBillingEnabled => V1CapabilityRegistry.storeBilling;
}

class V1StartupPhase {
  const V1StartupPhase({required this.id, required this.description});

  final String id;
  final String description;
}