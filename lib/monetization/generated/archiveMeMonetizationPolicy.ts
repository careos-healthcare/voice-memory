// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: config/monetization/archive_me_entitlement_matrix.json

export type PlanKind = "free" | "pro" | "legacyGrandfathered";
export type CapabilityId = "createTypedEntry" | "createVoiceRecording" | "openOriginalEntry" | "readSavedTranscript" | "editOriginalContent" | "playOriginalAudio" | "browseOriginalArchive" | "basicLocalSearch" | "openEvidenceSource" | "correctInterpretation" | "hideInterpretation" | "deleteOriginalContent" | "exportOriginalContent" | "downloadExistingCloudContent" | "deleteCloudContent" | "accountDeletion" | "privacySettings" | "purchaseRestoreAndManagement" | "accessLegalAndSupport" | "readExistingGeneratedOutput" | "firstEvidenceObservation" | "remoteObservationGeneration" | "firstEarlyComparison" | "ongoingComparisons" | "fullChangesHistoryGeneration" | "deepArchiveSynthesis" | "fullHistoryQuestion" | "periodicReviewGeneration" | "advancedEvidenceGrouping" | "remoteTranscription" | "embeddingGeneration";
export type AccessClass = "userOwned" | "freeProof" | "metered" | "proMetered" | "pro";
export type UsageMeterId = "remoteTranscriptionSeconds" | "remoteObservationGeneration" | "earlyComparisonGeneration" | "ongoingComparisonGeneration" | "deepArchiveSynthesis" | "archiveQuestion" | "periodicReview" | "embeddingGeneration";
export type PolicySubscriptionState = "free" | "trial" | "active" | "gracePeriod" | "billingIssue" | "expired" | "revoked" | "legacyGrandfathered" | "unknown";

export interface MonetizationCapability {
  readonly id: CapabilityId;
  readonly accessClass: AccessClass;
  readonly expiryBehaviour: string;
  readonly offlineBehaviour: string;
  readonly usageMeterId?: UsageMeterId;
  readonly copyKey: string;
}

export interface ArchiveMeMonetizationPolicy {
  readonly schemaVersion: 1;
  readonly policyVersion: string;
  readonly revenueCat: {
    readonly canonicalProEntitlementId: string;
    readonly acceptedLegacyEntitlementAliases: readonly string[];
    readonly legacyGrandfatheredProductIds: readonly string[];
    readonly currentOfferingPackageKinds: readonly string[];
    readonly blockedCurrentPackageKinds: readonly string[];
  };
  readonly plans: readonly {
    readonly id: string;
    readonly kind: PlanKind;
    readonly availableForNewPurchase?: boolean;
  }[];
  readonly subscriptionStates: readonly PolicySubscriptionState[];
  readonly customerFacingCopy: Readonly<Record<string, string>>;
  readonly capabilities: readonly MonetizationCapability[];
  readonly usageMeters: readonly {
    readonly id: UsageMeterId;
    readonly unit: "seconds" | "requests";
    readonly period: "billingPeriod";
    readonly productionConfigurationRequired: boolean;
  }[];
  readonly legacyMigrationRules: {
    readonly preserveOriginalContentAccess: true;
    readonly preserveGeneratedOutputReadAccess: true;
    readonly doNotConsumeFreeProofFromLegacyCounters: true;
    readonly honourActiveLegacyEntitlementAliases: true;
    readonly honourVerifiedLifetimePurchasersAsLegacyGrandfathered: true;
    readonly allowNewLifetimePurchases: false;
  };
}

export const archiveMeMonetizationPolicy =
  {
    "schemaVersion": 1,
    "policyVersion": "2026-08-01",
    "revenueCat": {
      "canonicalProEntitlementId": "archive_loop_pro",
      "acceptedLegacyEntitlementAliases": [
        "pro"
      ],
      "legacyGrandfatheredProductIds": [
        "archive_loop_pro_lifetime"
      ],
      "currentOfferingPackageKinds": [
        "monthly",
        "annual"
      ],
      "blockedCurrentPackageKinds": [
        "lifetime"
      ]
    },
    "plans": [
      {
        "id": "free",
        "kind": "free"
      },
      {
        "id": "pro_subscription",
        "kind": "pro"
      },
      {
        "id": "legacy_grandfathered",
        "kind": "legacyGrandfathered",
        "availableForNewPurchase": false
      }
    ],
    "subscriptionStates": [
      "free",
      "trial",
      "active",
      "gracePeriod",
      "billingIssue",
      "expired",
      "revoked",
      "legacyGrandfathered",
      "unknown"
    ],
    "customerFacingCopy": {
      "originalsStayYours": "Your recordings stay yours.",
      "existingResultsStayReadable": "Observations and comparisons already created remain available.",
      "firstObservationIncluded": "Your first valid evidence-backed observation is included.",
      "firstComparisonIncluded": "Your first valid two-moment comparison is included.",
      "ongoingComparisons": "Ongoing comparisons",
      "fullChangesHistory": "Full Changes history generation",
      "deeperArchiveAnalysis": "Deeper archive analysis",
      "fullHistoryQuestions": "Full-history questions",
      "periodicReviews": "Periodic reviews",
      "advancedEvidenceGrouping": "Advanced evidence grouping",
      "remoteTranscriptionAllowance": "Additional configured remote transcription",
      "remoteAnalysisAllowance": "Additional configured remote analysis",
      "restorePurchases": "Restore Purchases",
      "paywallHeadline": "Keep following what changes.",
      "paywallSupportingLine": "Your recordings stay yours. Pro unlocks ongoing comparisons and deeper archive analysis."
    },
    "capabilities": [
      {
        "id": "createTypedEntry",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "createVoiceRecording",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "openOriginalEntry",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "readSavedTranscript",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "editOriginalContent",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "playOriginalAudio",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "browseOriginalArchive",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "basicLocalSearch",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "openEvidenceSource",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "correctInterpretation",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "hideInterpretation",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "deleteOriginalContent",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "exportOriginalContent",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "downloadExistingCloudContent",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "requiresConnection",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "deleteCloudContent",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "requiresConnection",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "accountDeletion",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "requiresConnection",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "privacySettings",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowed",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "purchaseRestoreAndManagement",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "requiresConnection",
        "copyKey": "restorePurchases"
      },
      {
        "id": "accessLegalAndSupport",
        "accessClass": "userOwned",
        "expiryBehaviour": "alwaysAvailable",
        "offlineBehaviour": "allowedWhenLocal",
        "copyKey": "originalsStayYours"
      },
      {
        "id": "readExistingGeneratedOutput",
        "accessClass": "userOwned",
        "expiryBehaviour": "readOnlyAfterExpiry",
        "offlineBehaviour": "allowed",
        "copyKey": "existingResultsStayReadable"
      },
      {
        "id": "firstEvidenceObservation",
        "accessClass": "freeProof",
        "expiryBehaviour": "readOnlyAfterGeneration",
        "offlineBehaviour": "allowedWhenLocal",
        "copyKey": "firstObservationIncluded"
      },
      {
        "id": "remoteObservationGeneration",
        "accessClass": "metered",
        "expiryBehaviour": "planAllowanceAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "remoteObservationGeneration",
        "copyKey": "remoteAnalysisAllowance"
      },
      {
        "id": "firstEarlyComparison",
        "accessClass": "freeProof",
        "expiryBehaviour": "readOnlyAfterGeneration",
        "offlineBehaviour": "allowedWhenLocal",
        "copyKey": "firstComparisonIncluded"
      },
      {
        "id": "ongoingComparisons",
        "accessClass": "proMetered",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "ongoingComparisonGeneration",
        "copyKey": "ongoingComparisons"
      },
      {
        "id": "fullChangesHistoryGeneration",
        "accessClass": "proMetered",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "ongoingComparisonGeneration",
        "copyKey": "fullChangesHistory"
      },
      {
        "id": "deepArchiveSynthesis",
        "accessClass": "proMetered",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "deepArchiveSynthesis",
        "copyKey": "deeperArchiveAnalysis"
      },
      {
        "id": "fullHistoryQuestion",
        "accessClass": "proMetered",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "archiveQuestion",
        "copyKey": "fullHistoryQuestions"
      },
      {
        "id": "periodicReviewGeneration",
        "accessClass": "proMetered",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "periodicReview",
        "copyKey": "periodicReviews"
      },
      {
        "id": "advancedEvidenceGrouping",
        "accessClass": "pro",
        "expiryBehaviour": "noNewGenerationAfterExpiry",
        "offlineBehaviour": "allowedWhenLocal",
        "copyKey": "advancedEvidenceGrouping"
      },
      {
        "id": "remoteTranscription",
        "accessClass": "metered",
        "expiryBehaviour": "planAllowanceAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "remoteTranscriptionSeconds",
        "copyKey": "remoteTranscriptionAllowance"
      },
      {
        "id": "embeddingGeneration",
        "accessClass": "metered",
        "expiryBehaviour": "planAllowanceAfterExpiry",
        "offlineBehaviour": "requiresConnection",
        "usageMeterId": "embeddingGeneration",
        "copyKey": "remoteAnalysisAllowance"
      }
    ],
    "usageMeters": [
      {
        "id": "remoteTranscriptionSeconds",
        "unit": "seconds",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "remoteObservationGeneration",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "earlyComparisonGeneration",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "ongoingComparisonGeneration",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "deepArchiveSynthesis",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "archiveQuestion",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "periodicReview",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      },
      {
        "id": "embeddingGeneration",
        "unit": "requests",
        "period": "billingPeriod",
        "productionConfigurationRequired": true
      }
    ],
    "legacyMigrationRules": {
      "preserveOriginalContentAccess": true,
      "preserveGeneratedOutputReadAccess": true,
      "doNotConsumeFreeProofFromLegacyCounters": true,
      "honourActiveLegacyEntitlementAliases": true,
      "honourVerifiedLifetimePurchasersAsLegacyGrandfathered": true,
      "allowNewLifetimePurchases": false
    }
  } as const satisfies ArchiveMeMonetizationPolicy;

export const capabilityById: Readonly<Record<CapabilityId, MonetizationCapability>> =
  Object.freeze(Object.fromEntries(
    archiveMeMonetizationPolicy.capabilities.map((capability) => [capability.id, capability]),
  ) as Record<CapabilityId, MonetizationCapability>);
