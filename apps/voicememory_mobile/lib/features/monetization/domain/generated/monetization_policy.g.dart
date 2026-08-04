// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: config/monetization/archive_me_entitlement_matrix.json

enum PlanKind { free, pro, legacyGrandfathered }

enum CapabilityId {
  createTypedEntry,
  createVoiceRecording,
  openOriginalEntry,
  readSavedTranscript,
  editOriginalContent,
  playOriginalAudio,
  browseOriginalArchive,
  basicLocalSearch,
  openEvidenceSource,
  correctInterpretation,
  hideInterpretation,
  deleteOriginalContent,
  exportOriginalContent,
  downloadExistingCloudContent,
  deleteCloudContent,
  accountDeletion,
  privacySettings,
  purchaseRestoreAndManagement,
  accessLegalAndSupport,
  readExistingGeneratedOutput,
  firstEvidenceObservation,
  remoteObservationGeneration,
  firstEarlyComparison,
  ongoingComparisons,
  fullChangesHistoryGeneration,
  deepArchiveSynthesis,
  fullHistoryQuestion,
  periodicReviewGeneration,
  advancedEvidenceGrouping,
  remoteTranscription,
  embeddingGeneration,
}

enum AccessClass { userOwned, freeProof, metered, proMetered, pro }

enum UsageMeterId {
  remoteTranscriptionSeconds,
  remoteObservationGeneration,
  earlyComparisonGeneration,
  ongoingComparisonGeneration,
  deepArchiveSynthesis,
  archiveQuestion,
  periodicReview,
  embeddingGeneration,
}

enum PolicySubscriptionState { free, trial, active, gracePeriod, billingIssue, expired, revoked, legacyGrandfathered, unknown }

class MonetizationCapability {
  const MonetizationCapability({
    required this.id,
    required this.accessClass,
    required this.expiryBehaviour,
    required this.offlineBehaviour,
    required this.copyKey,
    this.usageMeterId,
  });

  final CapabilityId id;
  final AccessClass accessClass;
  final String expiryBehaviour;
  final String offlineBehaviour;
  final UsageMeterId? usageMeterId;
  final String copyKey;
}

abstract final class MonetizationPolicy {
  static const int schemaVersion = 1;
  static const String policyVersion = '2026-08-01';
  static const String canonicalProEntitlementId =
      'archive_loop_pro';
  static const Set<String> acceptedLegacyEntitlementAliases = {
    'pro',
  };
  static const Set<String> legacyGrandfatheredProductIds = {
    'archive_loop_pro_lifetime',
  };
  static const Set<String> currentOfferingPackageKinds = {
    'monthly',
    'annual',
  };
  static const Set<String> blockedCurrentPackageKinds = {
    'lifetime',
  };

  static const String originalsStayYours = 'Your recordings stay yours.';
  static const String existingResultsStayReadable = 'Observations and comparisons already created remain available.';
  static const String firstObservationIncluded = 'Your first valid evidence-backed observation is included.';
  static const String firstComparisonIncluded = 'Your first valid two-moment comparison is included.';
  static const String ongoingComparisons = 'Ongoing comparisons';
  static const String fullChangesHistory = 'Full Changes history generation';
  static const String deeperArchiveAnalysis = 'Deeper archive analysis';
  static const String fullHistoryQuestions = 'Full-history questions';
  static const String periodicReviews = 'Periodic reviews';
  static const String advancedEvidenceGrouping = 'Advanced evidence grouping';
  static const String remoteTranscriptionAllowance = 'Additional configured remote transcription';
  static const String remoteAnalysisAllowance = 'Additional configured remote analysis';
  static const String restorePurchases = 'Restore Purchases';
  static const String paywallHeadline = 'Keep following what changes.';
  static const String paywallSupportingLine = 'Your recordings stay yours. Pro unlocks ongoing comparisons and deeper archive analysis.';

  static const Map<CapabilityId, MonetizationCapability> capabilities = {
    CapabilityId.createTypedEntry: MonetizationCapability(
      id: CapabilityId.createTypedEntry,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.createVoiceRecording: MonetizationCapability(
      id: CapabilityId.createVoiceRecording,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.openOriginalEntry: MonetizationCapability(
      id: CapabilityId.openOriginalEntry,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.readSavedTranscript: MonetizationCapability(
      id: CapabilityId.readSavedTranscript,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.editOriginalContent: MonetizationCapability(
      id: CapabilityId.editOriginalContent,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.playOriginalAudio: MonetizationCapability(
      id: CapabilityId.playOriginalAudio,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.browseOriginalArchive: MonetizationCapability(
      id: CapabilityId.browseOriginalArchive,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.basicLocalSearch: MonetizationCapability(
      id: CapabilityId.basicLocalSearch,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.openEvidenceSource: MonetizationCapability(
      id: CapabilityId.openEvidenceSource,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.correctInterpretation: MonetizationCapability(
      id: CapabilityId.correctInterpretation,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.hideInterpretation: MonetizationCapability(
      id: CapabilityId.hideInterpretation,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.deleteOriginalContent: MonetizationCapability(
      id: CapabilityId.deleteOriginalContent,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.exportOriginalContent: MonetizationCapability(
      id: CapabilityId.exportOriginalContent,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.downloadExistingCloudContent: MonetizationCapability(
      id: CapabilityId.downloadExistingCloudContent,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'requiresConnection',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.deleteCloudContent: MonetizationCapability(
      id: CapabilityId.deleteCloudContent,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'requiresConnection',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.accountDeletion: MonetizationCapability(
      id: CapabilityId.accountDeletion,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'requiresConnection',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.privacySettings: MonetizationCapability(
      id: CapabilityId.privacySettings,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowed',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.purchaseRestoreAndManagement: MonetizationCapability(
      id: CapabilityId.purchaseRestoreAndManagement,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'requiresConnection',
      copyKey: 'restorePurchases',
    ),
    CapabilityId.accessLegalAndSupport: MonetizationCapability(
      id: CapabilityId.accessLegalAndSupport,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'alwaysAvailable',
      offlineBehaviour: 'allowedWhenLocal',
      copyKey: 'originalsStayYours',
    ),
    CapabilityId.readExistingGeneratedOutput: MonetizationCapability(
      id: CapabilityId.readExistingGeneratedOutput,
      accessClass: AccessClass.userOwned,
      expiryBehaviour: 'readOnlyAfterExpiry',
      offlineBehaviour: 'allowed',
      copyKey: 'existingResultsStayReadable',
    ),
    CapabilityId.firstEvidenceObservation: MonetizationCapability(
      id: CapabilityId.firstEvidenceObservation,
      accessClass: AccessClass.freeProof,
      expiryBehaviour: 'readOnlyAfterGeneration',
      offlineBehaviour: 'allowedWhenLocal',
      copyKey: 'firstObservationIncluded',
    ),
    CapabilityId.remoteObservationGeneration: MonetizationCapability(
      id: CapabilityId.remoteObservationGeneration,
      accessClass: AccessClass.metered,
      expiryBehaviour: 'planAllowanceAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.remoteObservationGeneration,
      copyKey: 'remoteAnalysisAllowance',
    ),
    CapabilityId.firstEarlyComparison: MonetizationCapability(
      id: CapabilityId.firstEarlyComparison,
      accessClass: AccessClass.freeProof,
      expiryBehaviour: 'readOnlyAfterGeneration',
      offlineBehaviour: 'allowedWhenLocal',
      copyKey: 'firstComparisonIncluded',
    ),
    CapabilityId.ongoingComparisons: MonetizationCapability(
      id: CapabilityId.ongoingComparisons,
      accessClass: AccessClass.proMetered,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.ongoingComparisonGeneration,
      copyKey: 'ongoingComparisons',
    ),
    CapabilityId.fullChangesHistoryGeneration: MonetizationCapability(
      id: CapabilityId.fullChangesHistoryGeneration,
      accessClass: AccessClass.proMetered,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.ongoingComparisonGeneration,
      copyKey: 'fullChangesHistory',
    ),
    CapabilityId.deepArchiveSynthesis: MonetizationCapability(
      id: CapabilityId.deepArchiveSynthesis,
      accessClass: AccessClass.proMetered,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.deepArchiveSynthesis,
      copyKey: 'deeperArchiveAnalysis',
    ),
    CapabilityId.fullHistoryQuestion: MonetizationCapability(
      id: CapabilityId.fullHistoryQuestion,
      accessClass: AccessClass.proMetered,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.archiveQuestion,
      copyKey: 'fullHistoryQuestions',
    ),
    CapabilityId.periodicReviewGeneration: MonetizationCapability(
      id: CapabilityId.periodicReviewGeneration,
      accessClass: AccessClass.proMetered,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.periodicReview,
      copyKey: 'periodicReviews',
    ),
    CapabilityId.advancedEvidenceGrouping: MonetizationCapability(
      id: CapabilityId.advancedEvidenceGrouping,
      accessClass: AccessClass.pro,
      expiryBehaviour: 'noNewGenerationAfterExpiry',
      offlineBehaviour: 'allowedWhenLocal',
      copyKey: 'advancedEvidenceGrouping',
    ),
    CapabilityId.remoteTranscription: MonetizationCapability(
      id: CapabilityId.remoteTranscription,
      accessClass: AccessClass.metered,
      expiryBehaviour: 'planAllowanceAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.remoteTranscriptionSeconds,
      copyKey: 'remoteTranscriptionAllowance',
    ),
    CapabilityId.embeddingGeneration: MonetizationCapability(
      id: CapabilityId.embeddingGeneration,
      accessClass: AccessClass.metered,
      expiryBehaviour: 'planAllowanceAfterExpiry',
      offlineBehaviour: 'requiresConnection',
      usageMeterId: UsageMeterId.embeddingGeneration,
      copyKey: 'remoteAnalysisAllowance',
    ),
  };

  static MonetizationCapability capability(CapabilityId id) => capabilities[id]!;
}
