/// Single source of truth for compile-time feature flags and preview inputs.
///
/// Production values are immutable `--dart-define` constants. Mutable test
/// overrides live separately in [testOverrides] and are never consulted unless
/// an existing feature explicitly opts into a test override.
abstract final class AppFeatureFlags {
  // Screenshot and marketing preview inputs.
  static const bool screenshotModeEnabled = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_MODE',
    defaultValue: false,
  );
  static const String screenshotRecordView = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RECORD_VIEW',
    defaultValue: 'return_day',
  );
  static const String screenshotRecordClean = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RECORD_CLEAN',
    defaultValue: '',
  );
  static const String screenshotJourneyStep = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_JOURNEY_STEP',
    defaultValue: '',
  );
  static const String screenshotFirstLoopStage = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE',
    defaultValue: '',
  );
  static const String screenshotReturnDayStage = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE',
    defaultValue: '',
  );
  static const String screenshotReturnCapture = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETURN_CAPTURE',
    defaultValue: 'same',
  );
  static const String screenshotCheckInOption = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_CHECK_IN_OPTION',
    defaultValue: 'same',
  );
  static const String screenshotHookFix = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_HOOK_FIX',
    defaultValue: '',
  );
  static const bool screenshotResultNextCheck = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RESULT_NEXT_CHECK',
    defaultValue: false,
  );
  static const bool screenshotUsefulResult = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_USEFUL_RESULT',
    defaultValue: false,
  );
  static const String screenshotActivationRescue = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ACTIVATION_RESCUE',
    defaultValue: '',
  );
  static const String screenshotRetention = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETENTION',
    defaultValue: '',
  );
  static const bool screenshotCompellingCheck = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_COMPELLING_CHECK',
    defaultValue: false,
  );
  static const bool screenshotRealReminder = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_REAL_REMINDER',
    defaultValue: false,
  );
  static const String screenshotObjective = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_OBJECTIVE',
    defaultValue: '',
  );
  static const bool screenshotPerspective = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PERSPECTIVE',
    defaultValue: false,
  );
  static const bool screenshotKindness = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_KINDNESS',
    defaultValue: false,
  );
  static const bool screenshotQuickHelp = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_QUICK_HELP',
    defaultValue: false,
  );
  static const bool screenshotKeyMoments = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS',
    defaultValue: false,
  );
  static const bool screenshotPatternMap = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERN_MAP',
    defaultValue: false,
  );
  static const bool screenshotFeedback = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_FEEDBACK',
    defaultValue: false,
  );
  static const bool screenshotArchiveMemory = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_MEMORY',
    defaultValue: false,
  );
  static const bool screenshotArchiveTimeline = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_TIMELINE',
    defaultValue: false,
  );
  static const bool screenshotPositioningRescue = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_POSITIONING_RESCUE',
    defaultValue: false,
  );
  static const bool screenshotAskArchive = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ASK_ARCHIVE',
    defaultValue: false,
  );
  static const bool screenshotArchiveClean = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_CLEAN',
    defaultValue: false,
  );
  static const bool screenshotPatternProfile = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERN_PROFILE',
    defaultValue: false,
  );
  static const bool screenshotPatternsClean = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERNS_CLEAN',
    defaultValue: false,
  );
  static const bool screenshotArchiveCompression = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_COMPRESSION',
    defaultValue: false,
  );
  static const bool screenshotMemoryQuality = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_MEMORY_QUALITY',
    defaultValue: false,
  );
  static const bool screenshotArchiveReview = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_REVIEW',
    defaultValue: false,
  );
  static const String screenshotDemo = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_DEMO',
    defaultValue: '',
  );
  static const String screenshotInputQuality = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_INPUT_QUALITY',
    defaultValue: '',
  );
  static const String screenshotLanguage = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_LANGUAGE',
    defaultValue: '',
  );

  // Focused QA preview inputs.
  static const String firstThreeSessionPreview = String.fromEnvironment(
    'FIRST_THREE_SESSION_PREVIEW',
    defaultValue: '',
  );
  static const bool archiveBeliefPreview = bool.fromEnvironment(
    'ARCHIVE_BELIEF_PREVIEW',
    defaultValue: false,
  );
  static const bool evidenceTimelinePreview = bool.fromEnvironment(
    'EVIDENCE_TIMELINE_PREVIEW',
    defaultValue: false,
  );
  static const bool weeklyReviewPreview = bool.fromEnvironment(
    'WEEKLY_REVIEW_PREVIEW',
    defaultValue: false,
  );
  static const String archiveIntelligencePreview = String.fromEnvironment(
    'ARCHIVE_INTELLIGENCE_PREVIEW',
    defaultValue: '',
  );

  // Demo gates use the same source, while mutable test forcing remains isolated.
  static const bool creatorDemoModeEnabled = bool.fromEnvironment(
    'ARCHIVEME_CREATOR_DEMO_MODE',
    defaultValue: false,
  );

  /// Enables Stripe Checkout surfaces where the distribution channel permits
  /// external purchase links. Native store billing remains the default.
  static const bool useWebStripeCheckout = bool.fromEnvironment(
    'USE_WEB_STRIPE_CHECKOUT',
    defaultValue: false,
  );

  /// Set only for iOS builds/storefronts whose review terms or entitlement
  /// explicitly permit external purchase links.
  static const bool allowIosWebStripeCheckout = bool.fromEnvironment(
    'ALLOW_IOS_WEB_STRIPE_CHECKOUT',
    defaultValue: false,
  );

  /// Set only for Android distributions/regions whose billing terms permit
  /// external purchase links.
  static const bool allowAndroidWebStripeCheckout = bool.fromEnvironment(
    'ALLOW_ANDROID_WEB_STRIPE_CHECKOUT',
    defaultValue: false,
  );

  static final AppFeatureFlagTestOverrides testOverrides =
      AppFeatureFlagTestOverrides._();
}

/// Mutable flags exclusively for tests.
///
/// Call [reset] in test tear-down to prevent state leaking between cases.
final class AppFeatureFlagTestOverrides {
  AppFeatureFlagTestOverrides._();

  bool archiveMeDemoEnabled = false;
  bool creatorDemoEnabled = false;

  void reset() {
    archiveMeDemoEnabled = false;
    creatorDemoEnabled = false;
  }
}
