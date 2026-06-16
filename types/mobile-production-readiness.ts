/** Mobile Production Readiness v1 — store proof, not product intelligence. */

export type StoreReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type ReleaseEvidenceId =
  | "testflight_uploaded"
  | "play_internal_uploaded"
  | "ios_purchase_tested"
  | "android_purchase_tested"
  | "push_notifications_tested"
  | "background_recording_tested"
  | "offline_mode_tested"
  | "sync_recovery_tested"
  | "revenuecat_store_tested"
  | "stripe_checkout_tested"
  | "restore_purchases_tested"
  | "ios_signing_release"
  | "android_signing_release";

export type StoreReadinessItemId =
  | "push_notifications"
  | "background_recording"
  | "offline_mode"
  | "sync_recovery"
  | "revenuecat"
  | "stripe"
  | "restore_purchases"
  | "ios_signing"
  | "android_signing"
  | "testflight"
  | "play_store";

export type ReleaseEvidenceRecord = {
  id: ReleaseEvidenceId;
  passed: boolean;
  recordedAt: string;
  source: string;
  note: string;
};

export type StructuralEvidenceSignal = {
  id: string;
  passed: boolean;
  note: string;
};

export type StoreReadinessItem = {
  id: StoreReadinessItemId;
  label: string;
  status: StoreReadinessStatus;
  requiredEvidence: ReleaseEvidenceId[];
  evidenceNotes: string[];
};

export type ReadinessPillarScore = {
  label: string;
  status: StoreReadinessStatus;
  passing: number;
  total: number;
  summary: string;
};

export type MobileProductionReadinessReport = {
  generatedAt: string;
  items: StoreReadinessItem[];
  unknownCount: number;
  failingCount: number;
  passingCount: number;
  productReadiness: ReadinessPillarScore;
  storeReadiness: ReadinessPillarScore;
  distributionReadiness: ReadinessPillarScore;
  lines: string[];
};
