/** Store Distribution Verification v1 — evidence-only, no manual PASS. */

export type StoreReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type StoreDistributionPillarId =
  | "signing"
  | "store_upload"
  | "install"
  | "purchase"
  | "restore";

export type StoreTrackEvidence = {
  success: boolean;
  build_uploaded: boolean;
  build_installed: boolean;
  onboarding_completed: boolean;
  record_completed: boolean;
  archive_viewed: boolean;
  purchase_completed: boolean;
  restore_completed: boolean;
  timestamp: string;
};

export type IosSigningEvidence = {
  success: boolean;
  archive_build_created: boolean;
  uploaded_to_app_store_connect: boolean;
  timestamp: string;
};

export type AndroidSigningEvidence = {
  success: boolean;
  signed_aab_created: boolean;
  uploaded_to_play_console: boolean;
  timestamp: string;
};

export type StoreDistributionPillarRow = {
  id: StoreDistributionPillarId;
  label: string;
  status: StoreReadinessStatus;
  evidenceFiles: string[];
  missingRequirements: string[];
};

export type StorePlatformDistributionSection = {
  platform: "ios" | "android";
  pillars: StoreDistributionPillarRow[];
  verdict: StoreReadinessStatus;
};

export type StoreDistributionReadinessReport = {
  generatedAt: string;
  ios: StorePlatformDistributionSection;
  android: StorePlatformDistributionSection;
  testflightProofPassing: boolean;
  playProofPassing: boolean;
  iosSigningPassing: boolean;
  androidSigningPassing: boolean;
};
