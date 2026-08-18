import fs from "node:fs";
import path from "node:path";

import {
  buildNativePushReadinessReport,
  isNativePushFullyVerified,
} from "@/lib/mobile/native-push-verification";
import { isRevenueCatProductionPassing } from "@/lib/mobile/revenuecat-production-verification";
import { isRestoreProductionPassing } from "@/lib/mobile/restore-production-verification";
import { isOfflineSyncProductionPassing } from "@/lib/mobile/offline-sync-production-verification";
import {
  isAndroidSigningPassing,
  isIosSigningPassing,
  isPlayProofPassing,
  isTestflightProofPassing,
} from "@/lib/mobile/store-distribution-verification";
import type {
  CommercialChecklistItem,
  CommercialEvidenceBase,
  CommercialEvidenceFileId,
  CommercialReadinessStatus,
  PurchaseJourneyEvidence,
  PurchaseJourneySteps,
  StorePlatformReadinessReport,
} from "@/types/mobile-commercial-readiness";

export const COMMERCIAL_EVIDENCE_DIR = path.join(process.cwd(), "mobile", "evidence");

const EVIDENCE_FILES: CommercialEvidenceFileId[] = [
  "ios_signing_tested",
  "android_signing_tested",
  "testflight_tested",
  "play_internal_tested",
  "revenuecat_store_tested",
  "restore_purchases_tested",
  "purchase_journey_tested",
  "offline_sync_tested",
];

function readJson<T>(fileId: CommercialEvidenceFileId): T | null {
  const filePath = path.join(COMMERCIAL_EVIDENCE_DIR, `${fileId}.json`);
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8")) as T;
  } catch {
    return null;
  }
}

export function readCommercialEvidence(
  fileId: CommercialEvidenceFileId,
): CommercialEvidenceBase | PurchaseJourneyEvidence | null {
  if (fileId === "purchase_journey_tested") {
    return readJson<PurchaseJourneyEvidence>(fileId);
  }
  return readJson<CommercialEvidenceBase>(fileId);
}

export function isCommercialEvidencePassing(fileId: CommercialEvidenceFileId): boolean {
  if (fileId === "native_push_verification") {
    return isNativePushFullyVerified();
  }
  if (fileId === "revenuecat_store_tested") {
    return isRevenueCatProductionPassing();
  }
  if (fileId === "restore_purchases_tested") {
    return isRestoreProductionPassing();
  }
  if (fileId === "offline_sync_tested") {
    return isOfflineSyncProductionPassing();
  }
  if (fileId === "testflight_tested") {
    return isTestflightProofPassing();
  }
  if (fileId === "play_internal_tested") {
    return isPlayProofPassing();
  }
  if (fileId === "ios_signing_tested") {
    return isIosSigningPassing();
  }
  if (fileId === "android_signing_tested") {
    return isAndroidSigningPassing();
  }
  const row = readCommercialEvidence(fileId);
  if (!row) return false;
  if (fileId === "purchase_journey_tested") {
    const journey = row as PurchaseJourneyEvidence;
    if (!journey.success) return false;
    const steps = journey.steps;
    return (
      steps.install &&
      steps.record &&
      steps.archive &&
      steps.pay &&
      steps.purchase &&
      steps.close_app &&
      steps.reopen &&
      steps.restore
    );
  }
  return row.success === true;
}

function itemStatus(passing: boolean, fileExists: boolean): CommercialReadinessStatus {
  if (passing) return "PASSING";
  if (!fileExists) return "UNKNOWN";
  return "FAILING";
}

function buildItem(
  id: string,
  label: string,
  evidenceFile: CommercialEvidenceFileId,
): CommercialChecklistItem {
  const exists =
    evidenceFile === "native_push_verification"
      ? fs.existsSync(path.join(COMMERCIAL_EVIDENCE_DIR, "native_push_verification.json"))
      : fs.existsSync(path.join(COMMERCIAL_EVIDENCE_DIR, `${evidenceFile}.json`));
  const passing = isCommercialEvidencePassing(evidenceFile);
  const row = evidenceFile === "native_push_verification" ? null : readCommercialEvidence(evidenceFile);
  const notes: string[] = [];
  if (row?.note) notes.push(row.note);
  if (row && !passing && evidenceFile === "purchase_journey_tested") {
    const steps = (row as PurchaseJourneyEvidence).steps;
    const missing = (Object.keys(steps) as (keyof PurchaseJourneySteps)[]).filter((k) => !steps[k]);
    notes.push(`Missing steps: ${missing.join(", ")}`);
  }
  if (evidenceFile === "native_push_verification" && !passing) {
    const push = buildNativePushReadinessReport();
    notes.push(
      `iOS ${push.ios.status}, Android ${push.android.status} — physical devices required`,
    );
  }
  return {
    id,
    label,
    status: itemStatus(passing, exists),
    evidenceFile,
    notes,
  };
}

export function buildAppleStoreReadinessReport(): StorePlatformReadinessReport {
  const items: CommercialChecklistItem[] = [
    buildItem("bundle_id", "Bundle ID configured", "ios_signing_tested"),
    buildItem("signing", "Release signing", "ios_signing_tested"),
    buildItem("provisioning", "Provisioning profile", "ios_signing_tested"),
    buildItem("testflight", "TestFlight", "testflight_tested"),
    buildItem("push", "Native push (physical devices)", "native_push_verification"),
    buildItem("revenuecat", "RevenueCat store purchase", "revenuecat_store_tested"),
    buildItem("restore", "Restore purchases", "restore_purchases_tested"),
  ];

  const passingCount = items.filter((i) => i.status === "PASSING").length;
  const failingCount = items.filter((i) => i.status === "FAILING").length;

  let verdict: CommercialReadinessStatus = "UNKNOWN";
  if (passingCount === items.length) verdict = "PASSING";
  else if (failingCount > 0) verdict = "FAILING";

  return {
    platform: "apple",
    generatedAt: new Date().toISOString(),
    items,
    verdict,
    passingCount,
    total: items.length,
  };
}

export function buildGooglePlayReadinessReport(): StorePlatformReadinessReport {
  const items: CommercialChecklistItem[] = [
    buildItem("signing", "Release signing", "android_signing_tested"),
    buildItem("internal_track", "Play internal track", "play_internal_tested"),
    buildItem("billing", "Play billing / RevenueCat", "revenuecat_store_tested"),
    buildItem("restore", "Restore purchases", "restore_purchases_tested"),
    buildItem("push", "Native push (physical devices)", "native_push_verification"),
  ];

  const passingCount = items.filter((i) => i.status === "PASSING").length;
  const failingCount = items.filter((i) => i.status === "FAILING").length;

  let verdict: CommercialReadinessStatus = "UNKNOWN";
  if (passingCount === items.length) verdict = "PASSING";
  else if (failingCount > 0) verdict = "FAILING";

  return {
    platform: "google",
    generatedAt: new Date().toISOString(),
    items,
    verdict,
    passingCount,
    total: items.length,
  };
}

export function listCommercialEvidenceIds(): CommercialEvidenceFileId[] {
  return [...EVIDENCE_FILES];
}
