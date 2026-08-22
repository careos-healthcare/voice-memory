/** Restore purchase production verification v1 — reinstall journey evidence only. */

export type RestoreReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type RestorePurchasesEvidence = {
  success: boolean;
  device: string;
  platform: string;
  timestamp: string;
};

export type RestoreProductionReport = {
  generatedAt: string;
  status: RestoreReadinessStatus;
  evidence: RestorePurchasesEvidence | null;
  evidencePath: string;
  structuralRestorePresent: boolean;
  missingRequirements: string[];
  summary: string;
};
