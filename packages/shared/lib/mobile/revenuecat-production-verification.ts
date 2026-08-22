import fs from "node:fs";
import path from "node:path";

import { collectStructuralEvidenceSignals } from "@/lib/mobile/release-evidence";
import type {
  RevenueCatProductionReport,
  RevenueCatReadinessStatus,
  RevenueCatStoreEvidence,
} from "@/types/revenuecat-production-verification";

export const REVENUECAT_STORE_EVIDENCE_PATH = path.join(
  process.cwd(),
  "mobile",
  "evidence",
  "revenuecat_store_tested.json",
);

export function emptyRevenueCatStoreEvidence(): RevenueCatStoreEvidence {
  return {
    success: false,
    device: "",
    platform: "",
    offering_loaded: false,
    purchase_completed: false,
    entitlement_received: false,
    restore_completed: false,
    timestamp: "",
  };
}

export function readRevenueCatStoreEvidence(): RevenueCatStoreEvidence | null {
  if (!fs.existsSync(REVENUECAT_STORE_EVIDENCE_PATH)) return null;
  try {
    const raw = fs.readFileSync(REVENUECAT_STORE_EVIDENCE_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<RevenueCatStoreEvidence>;
    return {
      ...emptyRevenueCatStoreEvidence(),
      ...parsed,
      success: parsed.success === true,
      offering_loaded: parsed.offering_loaded === true,
      purchase_completed: parsed.purchase_completed === true,
      entitlement_received: parsed.entitlement_received === true,
      restore_completed: parsed.restore_completed === true,
      device: parsed.device ?? "",
      platform: parsed.platform ?? "",
      timestamp: parsed.timestamp ?? "",
    };
  } catch {
    return null;
  }
}

/** Production pass — real subscription journey on a physical device. */
export function isRevenueCatProductionPassing(
  evidence: RevenueCatStoreEvidence | null = readRevenueCatStoreEvidence(),
): boolean {
  if (!evidence) return false;
  return (
    evidence.purchase_completed === true &&
    evidence.entitlement_received === true &&
    evidence.restore_completed === true &&
    evidence.success === true
  );
}

export function revenueCatProductionMissingRequirements(
  evidence: RevenueCatStoreEvidence | null = readRevenueCatStoreEvidence(),
): string[] {
  if (!evidence) {
    return [
      "missing mobile/evidence/revenuecat_store_tested.json",
      "run Flutter /revenuecat-verify on a physical device",
    ];
  }
  const missing: string[] = [];
  if (!evidence.offering_loaded) missing.push("offering_loaded");
  if (!evidence.purchase_completed) missing.push("purchase_completed");
  if (!evidence.entitlement_received) missing.push("entitlement_received");
  if (!evidence.restore_completed) missing.push("restore_completed");
  if (!evidence.success) missing.push("success");
  if (!evidence.timestamp) missing.push("timestamp");
  if (!evidence.platform) missing.push("platform");
  if (!evidence.device) missing.push("device");
  return missing;
}

function isRevenueCatStructurallyIntegrated(): boolean {
  const signal = collectStructuralEvidenceSignals().find((s) => s.id === "revenuecat_absent");
  return signal?.passed === true;
}

export function resolveRevenueCatReadinessStatus(): RevenueCatReadinessStatus {
  if (!isRevenueCatStructurallyIntegrated()) return "FAILING";
  const evidence = readRevenueCatStoreEvidence();
  if (!evidence) return "UNKNOWN";
  if (isRevenueCatProductionPassing(evidence)) return "PASSING";
  return "FAILING";
}

export function buildRevenueCatProductionReport(): RevenueCatProductionReport {
  const evidence = readRevenueCatStoreEvidence();
  const structuralIntegrated = isRevenueCatStructurallyIntegrated();
  const status = resolveRevenueCatReadinessStatus();
  const missingRequirements = revenueCatProductionMissingRequirements(evidence);

  let summary: string;
  if (!structuralIntegrated) {
    summary = "RevenueCat SDK not integrated in Flutter app";
  } else if (!evidence) {
    summary = "No committed evidence — complete /revenuecat-verify on device";
  } else if (status === "PASSING") {
    summary = `Production purchase verified (${evidence.platform} · ${evidence.device})`;
  } else {
    summary = `Evidence on file — missing: ${missingRequirements.join(", ")}`;
  }

  return {
    generatedAt: new Date().toISOString(),
    status,
    evidence,
    evidencePath: REVENUECAT_STORE_EVIDENCE_PATH,
    structuralIntegrated,
    missingRequirements,
    summary,
  };
}
