/// Machine-readable launch product contract — nine customer capabilities,
/// canonical promise, and enforcement patterns for CI/tests.
abstract final class V1LaunchProductContract {
  V1LaunchProductContract._();

  static const canonicalPromise =
      'A private voice archive that preserves what you actually said and '
      'cautiously shows evidence-backed changes over time.';

  /// The nine launch capabilities (voice + text capture count separately in spec).
  static const launchCapabilities = [
    V1LaunchCapability(
      id: 'voice_capture',
      label: 'Fast voice capture',
      routes: ['/record'],
    ),
    V1LaunchCapability(
      id: 'text_capture',
      label: 'Fast text capture',
      routes: ['/quick-capture'],
    ),
    V1LaunchCapability(
      id: 'private_storage',
      label: 'Reliable private storage',
      routes: ['/account', '/security'],
    ),
    V1LaunchCapability(
      id: 'original_transcripts',
      label: 'Original transcript archive',
      routes: ['/archive-belief', '/entry/:id'],
    ),
    V1LaunchCapability(
      id: 'archive_search',
      label: 'Search',
      routes: ['/archive-belief'],
    ),
    V1LaunchCapability(
      id: 'cautious_patterns',
      label: 'Cautious verified patterns and changes',
      routes: ['/belief-changes', '/belief-detail'],
    ),
    V1LaunchCapability(
      id: 'exact_evidence',
      label: 'Exact supporting evidence',
      routes: ['/belief-evidence'],
    ),
    V1LaunchCapability(
      id: 'corrections_suppression',
      label: 'Correction and suppression controls',
      routes: ['/entry/:id', '/belief-evidence'],
    ),
    V1LaunchCapability(
      id: 'export_deletion',
      label: 'Export and deletion',
      routes: ['/export', '/delete-account'],
    ),
    V1LaunchCapability(
      id: 'free_beta_unlimited_local_archive',
      label: 'Free beta — unlimited local archive',
      routes: ['/archive-belief', '/entry/:id'],
    ),
  ];

  /// Production screens that must not render these widgets when [enableV1Only].
  static const quarantinedProductionWidgets = [
    'WeeklyGrowthPreviewCard',
    'BetaFeedbackSheet',
    'AiAccuracyFeedbackStore',
    'RememberThisButton',
    'SaveAsFactButton',
    'PinEntryButton',
    'BetaFeedbackCaptureCard',
    'WeeklyArchiveReviewCard',
    'DailyArchiveMemoryCard',
  ];

  /// Copy patterns forbidden on launch-facing surfaces.
  static const bannedClaimPatterns = [
    'AI Accuracy',
    'Weekly archive reviews',
    'Timeline views over time',
    'diagnosis',
    'therapy session',
    'guaranteed transformation',
    'hidden truth',
    'life intelligence',
  ];

  /// Trust-forward phrases encouraged on proof surfaces.
  static const trustPhrases = [
    'Your archive noticed',
    'This may be changing',
    'Based on these entries',
    'You can correct or hide this',
    'Not therapy or medical advice',
  ];

  /// Startup services allowed in essential phase (blocking navigation).
  static const essentialStartupServices = [
    'AppStoragePaths.configureFromDeviceInfo',
    'AppServices.initializeEssential',
    'reconcileArchiveCorrectionStoreForActiveNamespace',
    'onboardingGate.refresh',
  ];

  /// Startup services deferred to optional async phase.
  static const optionalStartupServices = [
    'RevenueCatService.initialize',
    'BillingService.startListening',
    'ProductAnalytics.initialize',
    'OfflineVaultRecoveryLaunchController.prepareScan',
  ];
}

class V1LaunchCapability {
  const V1LaunchCapability({
    required this.id,
    required this.label,
    required this.routes,
  });

  final String id;
  final String label;
  final List<String> routes;
}