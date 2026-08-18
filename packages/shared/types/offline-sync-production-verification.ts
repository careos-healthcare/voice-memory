/** Offline sync production verification v1 — physical device evidence only. */

export type OfflineSyncReadinessStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type OfflineSyncEvidence = {
  success: boolean;
  device: string;
  platform: string;
  reflections_recorded_offline: number;
  reflections_synced: number;
  belief_preserved: boolean;
  evidence_preserved: boolean;
  timestamp: string;
  marketing_version?: string;
  build_number?: number | string;
  commit_sha?: string;
};

export type OfflineSyncProductionReport = {
  generatedAt: string;
  status: OfflineSyncReadinessStatus;
  evidence: OfflineSyncEvidence | null;
  evidencePath: string;
  missingRequirements: string[];
  summary: string;
};
