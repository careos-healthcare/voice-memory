/** RevenueCat production verification v1 — physical store purchase evidence only. */

export type RevenueCatReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type RevenueCatStoreEvidence = {
  success: boolean;
  device: string;
  platform: string;
  offering_loaded: boolean;
  purchase_completed: boolean;
  entitlement_received: boolean;
  restore_completed: boolean;
  timestamp: string;
  /** Optional diagnostics from device export */
  sdk_initialized?: boolean;
  product_ids?: string[];
  app_user_id?: string | null;
  entitlement_ids?: string[];
  note?: string;
};

export type RevenueCatProductionReport = {
  generatedAt: string;
  status: RevenueCatReadinessStatus;
  evidence: RevenueCatStoreEvidence | null;
  evidencePath: string;
  structuralIntegrated: boolean;
  missingRequirements: string[];
  summary: string;
};
