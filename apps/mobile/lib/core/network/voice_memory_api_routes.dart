/// HTTP verbs supported by the Next.js App Router handlers in `apps/api`.
enum VoiceMemoryHttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

/// A single Next.js `/api/*` route with its primary HTTP method(s).
final class VoiceMemoryApiEndpoint {
  const VoiceMemoryApiEndpoint(this.path, this.methods);

  final String path;
  final Set<VoiceMemoryHttpMethod> methods;

  bool supports(VoiceMemoryHttpMethod method) => methods.contains(method);
}

/// Typed catalog of every handler under `apps/api/app/api/**/route.ts`.
///
/// Mobile clients must reference these constants instead of string literals so
/// path drift against the backend is caught at compile time.
abstract final class VoiceMemoryApiRoutes {
  VoiceMemoryApiRoutes._();

  // — Auth —
  static const authSendCode = VoiceMemoryApiEndpoint(
    '/api/auth/send-code',
    {VoiceMemoryHttpMethod.post},
  );
  static const authVerify = VoiceMemoryApiEndpoint(
    '/api/auth/verify',
    {VoiceMemoryHttpMethod.post},
  );
  static const authSession = VoiceMemoryApiEndpoint(
    '/api/auth/session',
    {VoiceMemoryHttpMethod.get},
  );
  static const authSignOut = VoiceMemoryApiEndpoint(
    '/api/auth/signout',
    {VoiceMemoryHttpMethod.post},
  );

  // — Billing —
  static const billingEntitlements = VoiceMemoryApiEndpoint(
    '/api/billing/entitlements',
    {VoiceMemoryHttpMethod.get},
  );
  static const billingCheckout = VoiceMemoryApiEndpoint(
    '/api/billing/checkout',
    {VoiceMemoryHttpMethod.post},
  );
  static const billingConfig = VoiceMemoryApiEndpoint(
    '/api/billing/config',
    {VoiceMemoryHttpMethod.get},
  );
  static const billingWebhook = VoiceMemoryApiEndpoint(
    '/api/billing/webhook',
    {VoiceMemoryHttpMethod.post},
  );

  // — Capture & analysis —
  static const captureAttest = VoiceMemoryApiEndpoint(
    '/api/capture/attest',
    {VoiceMemoryHttpMethod.post},
  );
  static const analyze = VoiceMemoryApiEndpoint(
    '/api/analyze',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const transcribe = VoiceMemoryApiEndpoint(
    '/api/transcribe',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const atmosphere = VoiceMemoryApiEndpoint(
    '/api/atmosphere',
    {VoiceMemoryHttpMethod.post},
  );

  // — Live audio —
  static const liveAudioSession = VoiceMemoryApiEndpoint(
    '/api/live-audio/session',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const liveAudioRecover = VoiceMemoryApiEndpoint(
    '/api/live-audio/recover',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const liveAudioVaultRecovery = VoiceMemoryApiEndpoint(
    '/api/live-audio/vault-recovery',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const liveAudioWebSocket = VoiceMemoryApiEndpoint(
    '/api/live-audio/ws',
    {VoiceMemoryHttpMethod.get},
  );

  // — Sync & journal —
  static const syncManifest = VoiceMemoryApiEndpoint(
    '/api/sync/manifest',
    {VoiceMemoryHttpMethod.get},
  );
  static const syncPull = VoiceMemoryApiEndpoint(
    '/api/sync/pull',
    {VoiceMemoryHttpMethod.get},
  );
  static const syncChanges = VoiceMemoryApiEndpoint(
    '/api/sync/changes',
    {VoiceMemoryHttpMethod.get},
  );
  static const syncPush = VoiceMemoryApiEndpoint(
    '/api/sync/push',
    {VoiceMemoryHttpMethod.post},
  );
  static const journal = VoiceMemoryApiEndpoint(
    '/api/journal',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const journalExport = VoiceMemoryApiEndpoint(
    '/api/journal/export',
    {VoiceMemoryHttpMethod.get},
  );

  // — Account & user data —
  static const accountDelete = VoiceMemoryApiEndpoint(
    '/api/account/delete',
    {VoiceMemoryHttpMethod.post},
  );
  static const userData = VoiceMemoryApiEndpoint(
    '/api/user/data',
    {VoiceMemoryHttpMethod.delete},
  );

  // — Insights —
  static const insightsCorrections = VoiceMemoryApiEndpoint(
    '/api/insights/corrections',
    {VoiceMemoryHttpMethod.post},
  );
  static const insightsEvidence = VoiceMemoryApiEndpoint(
    '/api/insights/evidence',
    {VoiceMemoryHttpMethod.post},
  );
  static const insightsWeeklyStory = VoiceMemoryApiEndpoint(
    '/api/insights/weekly-story',
    {VoiceMemoryHttpMethod.get},
  );
  static const insightsComparison = VoiceMemoryApiEndpoint(
    '/api/insights/comparison',
    {VoiceMemoryHttpMethod.get},
  );

  // — Ledger —
  static const ledgerBulkImport = VoiceMemoryApiEndpoint(
    '/api/ledger/bulk-import',
    {VoiceMemoryHttpMethod.post},
  );

  // — Onboarding —
  static const onboardingBrainDump = VoiceMemoryApiEndpoint(
    '/api/onboarding/brain-dump',
    {VoiceMemoryHttpMethod.post},
  );

  // — Relationships & consent —
  static const userRelationships = VoiceMemoryApiEndpoint(
    '/api/user-relationships',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );
  static const coachConsentIssue = VoiceMemoryApiEndpoint(
    '/api/coach/consent/issue',
    {VoiceMemoryHttpMethod.post},
  );
  static const coachConsentVerify = VoiceMemoryApiEndpoint(
    '/api/coach/consent/verify',
    {VoiceMemoryHttpMethod.post},
  );

  // — Archive synthesis —
  static const archiveSynthesis = VoiceMemoryApiEndpoint(
    '/api/archive-synthesis',
    {VoiceMemoryHttpMethod.post},
  );

  // — Push & internal debug —
  static const pushRegister = VoiceMemoryApiEndpoint(
    '/api/push/register',
    {VoiceMemoryHttpMethod.post},
  );
  static const internalSendTestPush = VoiceMemoryApiEndpoint(
    '/api/internal/send-test-push',
    {VoiceMemoryHttpMethod.post},
  );
  static const internalCuriosityLoopDispatch = VoiceMemoryApiEndpoint(
    '/api/internal/curiosity-loop/dispatch',
    {VoiceMemoryHttpMethod.post},
  );
  static const internalArchiveMonthlyReview = VoiceMemoryApiEndpoint(
    '/api/internal/archive-monthly-review',
    {VoiceMemoryHttpMethod.post},
  );
  static const internalAuthEnv = VoiceMemoryApiEndpoint(
    '/api/internal/auth-env',
    {VoiceMemoryHttpMethod.get},
  );

  // — Health —
  static const health = VoiceMemoryApiEndpoint(
    '/api/health',
    {VoiceMemoryHttpMethod.get},
  );
  static const healthz = VoiceMemoryApiEndpoint(
    '/api/healthz',
    {VoiceMemoryHttpMethod.get},
  );

  // — Resurfacing & metrics —
  static const resurfacingFeedback = VoiceMemoryApiEndpoint(
    '/api/resurfacing/feedback',
    {VoiceMemoryHttpMethod.post},
  );
  static const resurfacingFeedbackSummary = VoiceMemoryApiEndpoint(
    '/api/resurfacing/feedback/summary',
    {VoiceMemoryHttpMethod.get},
  );
  static const metricsResurfacing = VoiceMemoryApiEndpoint(
    '/api/metrics/resurfacing',
    {VoiceMemoryHttpMethod.get, VoiceMemoryHttpMethod.post},
  );

  // — Reflection —
  static const weeklyReflection = VoiceMemoryApiEndpoint(
    '/api/weekly-reflection',
    {VoiceMemoryHttpMethod.post},
  );

  /// Every catalogued endpoint — useful for parity tests against the backend.
  static const List<VoiceMemoryApiEndpoint> all = [
    authSendCode,
    authVerify,
    authSession,
    authSignOut,
    billingEntitlements,
    billingCheckout,
    billingConfig,
    billingWebhook,
    captureAttest,
    analyze,
    transcribe,
    atmosphere,
    liveAudioSession,
    liveAudioRecover,
    liveAudioVaultRecovery,
    liveAudioWebSocket,
    syncManifest,
    syncPull,
    syncChanges,
    syncPush,
    journal,
    journalExport,
    accountDelete,
    userData,
    insightsCorrections,
    insightsEvidence,
    insightsWeeklyStory,
    insightsComparison,
    ledgerBulkImport,
    onboardingBrainDump,
    userRelationships,
    coachConsentIssue,
    coachConsentVerify,
    archiveSynthesis,
    pushRegister,
    internalSendTestPush,
    internalCuriosityLoopDispatch,
    internalArchiveMonthlyReview,
    internalAuthEnv,
    health,
    healthz,
    resurfacingFeedback,
    resurfacingFeedbackSummary,
    metricsResurfacing,
    weeklyReflection,
  ];

  static String journalEntry(String id) => '/api/journal/$id';

  static VoiceMemoryApiEndpoint journalEntryEndpoint(String id) =>
      VoiceMemoryApiEndpoint(journalEntry(id), {
        VoiceMemoryHttpMethod.put,
        VoiceMemoryHttpMethod.delete,
      });

  static String userRelationship(String id) => '/api/user-relationships/$id';

  static VoiceMemoryApiEndpoint userRelationshipEndpoint(String id) =>
      VoiceMemoryApiEndpoint(userRelationship(id), {
        VoiceMemoryHttpMethod.patch,
      });
}