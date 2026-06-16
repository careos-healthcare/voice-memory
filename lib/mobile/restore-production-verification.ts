import fs from "node:fs";
import path from "node:path";

import { collectStructuralEvidenceSignals } from "@/lib/mobile/release-evidence";
import type {
  RestoreProductionReport,
  RestorePurchasesEvidence,
  RestoreReadinessStatus,
} from "@/types/restore-production-verification";

export const RESTORE_PURCHASES_EVIDENCE_PATH = path.join(
  process.cwd(),
  "mobile",
  "evidence",
  "restore_purchases_tested.json",
);

export function emptyRestorePurchasesEvidence(): RestorePurchasesEvidence {
  return {
    success: false,
    device: "",
    platform: "",
    timestamp: "",
  };
}

export function readRestorePurchasesEvidence(): RestorePurchasesEvidence | null {
  if (!fs.existsSync(RESTORE_PURCHASES_EVIDENCE_PATH)) return null;
  try {
    const raw = fs.readFileSync(RESTORE_PURCHASES_EVIDENCE_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<RestorePurchasesEvidence>;
    return {
      success: parsed.success === true,
      device: parsed.device ?? "",
      platform: parsed.platform ?? "",
      timestamp: parsed.timestamp ?? "",
    };
  } catch {
    return null;
  }
}

/** Production pass — restore after delete + reinstall returns active entitlement. */
export function isRestoreProductionPassing(
  evidence: RestorePurchasesEvidence | null = readRestorePurchasesEvidence(),
): boolean {
  if (!evidence) return false;
  return evidence.success === true;
}

export function restoreProductionMissingRequirements(
  evidence: RestorePurchasesEvidence | null = readRestorePurchasesEvidence(),
): string[] {
  if (!evidence) {
    return [
      "missing mobile/evidence/restore_purchases_tested.json",
      "complete purchase → delete app → reinstall → restore on device",
    ];
  }
  const missing: string[] = [];
  if (!evidence.success) missing.push("success");
  if (!evidence.timestamp) missing.push("timestamp");
  if (!evidence.platform) missing.push("platform");
  if (!evidence.device) missing.push("device");
  return missing;
}

function isRestoreStructurallyPresent(): boolean {
  const signal = collectStructuralEvidenceSignals().find((s) => s.id === "restore_absent");
  return signal?.passed === true;
}

export function resolveRestoreReadinessStatus(): RestoreReadinessStatus {
  if (!isRestoreStructurallyPresent()) return "FAILING";
  const evidence = readRestorePurchasesEvidence();
  if (!evidence) return "UNKNOWN";
  if (isRestoreProductionPassing(evidence)) return "PASSING";
  return "FAILING";
}

export function buildRestoreProductionReport(): RestoreProductionReport {
  const evidence = readRestorePurchasesEvidence();
  const structuralRestorePresent = isRestoreStructurallyPresent();
  const status = resolveRestoreReadinessStatus();
  const missingRequirements = restoreProductionMissingRequirements(evidence);

  let summary: string;
  if (!structuralRestorePresent) {
    summary = "No restore purchases flow in Flutter app";
  } else if (!evidence) {
    summary = "No committed evidence — complete /restore-production-verify on device";
  } else if (status === "PASSING") {
    summary = `Restore after reinstall verified (${evidence.platform} · ${evidence.device})`;
  } else {
    summary = `Evidence on file — missing: ${missingRequirements.join(", ")}`;
  }

  return {
    generatedAt: new Date().toISOString(),
    status,
    evidence,
    evidencePath: RESTORE_PURCHASES_EVIDENCE_PATH,
    structuralRestorePresent,
    missingRequirements,
    summary,
  };
}
