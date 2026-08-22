/** Mobile Commercial Readiness v1 — evidence-only launch blockers. */

export type CommercialReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type MobilePrimaryPlatformVerdict = "COMPANION_APP" | "PRIMARY_PLATFORM";

export type CommercialEvidenceFileId =
  | "ios_signing_tested"
  | "android_signing_tested"
  | "testflight_tested"
  | "play_internal_tested"
  | "revenuecat_store_tested"
  | "restore_purchases_tested"
  | "purchase_journey_tested"
  | "offline_sync_tested"
  | "native_push_verification";

export type CommercialEvidenceBase = {
  success: boolean;
  platform?: string | null;
  device?: string | null;
  tester?: string | null;
  timestamp?: string | null;
  note?: string;
};

export type PurchaseJourneySteps = {
  install: boolean;
  record: boolean;
  archive: boolean;
  pay: boolean;
  purchase: boolean;
  close_app: boolean;
  reopen: boolean;
  restore: boolean;
};

export type PurchaseJourneyEvidence = CommercialEvidenceBase & {
  steps: PurchaseJourneySteps;
};

export type CommercialChecklistItem = {
  id: string;
  label: string;
  status: CommercialReadinessStatus;
  evidenceFile: CommercialEvidenceFileId;
  notes: string[];
};

export type StorePlatformReadinessReport = {
  platform: "apple" | "google";
  generatedAt: string;
  items: CommercialChecklistItem[];
  verdict: CommercialReadinessStatus;
  passingCount: number;
  total: number;
};

export type MobilePrimaryPlatformReport = {
  generatedAt: string;
  verdict: MobilePrimaryPlatformVerdict;
  verdictLabel: "MOBILE_PRIMARY_PLATFORM_VERDICT";
  reasons: string[];
  evidencePassing: string[];
  evidenceFailing: string[];
  structuralFailures: string[];
  journeyCompleteOnDevice: boolean;
};
