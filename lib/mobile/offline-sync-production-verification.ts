import fs from "node:fs";
import path from "node:path";

import type {
  OfflineSyncEvidence,
  OfflineSyncProductionReport,
  OfflineSyncReadinessStatus,
} from "@/types/offline-sync-production-verification";

export const OFFLINE_SYNC_EVIDENCE_PATH = path.join(
  process.cwd(),
  "mobile",
  "evidence",
  "offline_sync_tested.json",
);

export function emptyOfflineSyncEvidence(): OfflineSyncEvidence {
  return {
    success: false,
    device: "",
    platform: "",
    reflections_recorded_offline: 0,
    reflections_synced: 0,
    belief_preserved: false,
    evidence_preserved: false,
    timestamp: "",
  };
}

export function readOfflineSyncEvidence(): OfflineSyncEvidence | null {
  if (!fs.existsSync(OFFLINE_SYNC_EVIDENCE_PATH)) return null;
  try {
    const raw = fs.readFileSync(OFFLINE_SYNC_EVIDENCE_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<OfflineSyncEvidence>;
    return {
      success: parsed.success === true,
      device: parsed.device ?? "",
      platform: parsed.platform ?? "",
      reflections_recorded_offline: Number(parsed.reflections_recorded_offline) || 0,
      reflections_synced: Number(parsed.reflections_synced) || 0,
      belief_preserved: parsed.belief_preserved === true,
      evidence_preserved: parsed.evidence_preserved === true,
      timestamp: parsed.timestamp ?? "",
    };
  } catch {
    return null;
  }
}

export function isOfflineSyncProductionPassing(
  evidence: OfflineSyncEvidence | null = readOfflineSyncEvidence(),
): boolean {
  if (!evidence) return false;
  return (
    evidence.success === true &&
    evidence.belief_preserved === true &&
    evidence.evidence_preserved === true &&
    evidence.reflections_recorded_offline > 0 &&
    evidence.reflections_recorded_offline === evidence.reflections_synced
  );
}

export function offlineSyncProductionMissingRequirements(
  evidence: OfflineSyncEvidence | null = readOfflineSyncEvidence(),
): string[] {
  if (!evidence) {
    return [
      "missing mobile/evidence/offline_sync_tested.json",
      "complete offline flow on physical device via /offline-sync-verify",
    ];
  }
  const missing: string[] = [];
  if (!evidence.success) missing.push("success");
  if (!evidence.belief_preserved) missing.push("belief_preserved");
  if (!evidence.evidence_preserved) missing.push("evidence_preserved");
  if (evidence.reflections_recorded_offline === 0) {
    missing.push("reflections_recorded_offline");
  }
  if (evidence.reflections_recorded_offline !== evidence.reflections_synced) {
    missing.push("reflections_recorded_offline must equal reflections_synced");
  }
  if (!evidence.timestamp) missing.push("timestamp");
  if (!evidence.platform) missing.push("platform");
  if (!evidence.device) missing.push("device");
  return missing;
}

export function resolveOfflineSyncReadinessStatus(): OfflineSyncReadinessStatus {
  const evidence = readOfflineSyncEvidence();
  if (!evidence) return "UNKNOWN";
  if (isOfflineSyncProductionPassing(evidence)) return "PASSING";
  return "FAILING";
}

export function buildOfflineSyncProductionReport(): OfflineSyncProductionReport {
  const evidence = readOfflineSyncEvidence();
  const status = resolveOfflineSyncReadinessStatus();
  const missingRequirements = offlineSyncProductionMissingRequirements(evidence);

  let summary: string;
  if (!evidence) {
    summary = "No committed evidence — complete /offline-sync-verify on a physical device";
  } else if (status === "PASSING") {
    summary = `Offline sync verified (${evidence.platform} · ${evidence.device}) — ${evidence.reflections_synced} reflections`;
  } else {
    summary = `Evidence on file — missing: ${missingRequirements.join(", ")}`;
  }

  return {
    generatedAt: new Date().toISOString(),
    status,
    evidence,
    evidencePath: OFFLINE_SYNC_EVIDENCE_PATH,
    missingRequirements,
    summary,
  };
}
