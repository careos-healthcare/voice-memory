import fs from "node:fs";
import path from "node:path";

import type {
  AndroidSigningEvidence,
  IosSigningEvidence,
  StoreDistributionPillarId,
  StoreDistributionPillarRow,
  StoreDistributionReadinessReport,
  StorePlatformDistributionSection,
  StoreReadinessStatus,
  StoreTrackEvidence,
} from "@/types/store-distribution-verification";

const EVIDENCE_DIR = path.join(process.cwd(), "mobile", "evidence");

export const TESTFLIGHT_EVIDENCE_PATH = path.join(
  EVIDENCE_DIR,
  "testflight_tested.json",
);
export const PLAY_INTERNAL_EVIDENCE_PATH = path.join(
  EVIDENCE_DIR,
  "play_internal_tested.json",
);
export const IOS_SIGNING_EVIDENCE_PATH = path.join(
  EVIDENCE_DIR,
  "ios_signing_tested.json",
);
export const ANDROID_SIGNING_EVIDENCE_PATH = path.join(
  EVIDENCE_DIR,
  "android_signing_tested.json",
);

const TRACK_BOOLEAN_FIELDS: (keyof Omit<StoreTrackEvidence, "timestamp">)[] = [
  "success",
  "build_uploaded",
  "build_installed",
  "onboarding_completed",
  "record_completed",
  "archive_viewed",
  "purchase_completed",
  "restore_completed",
];

function readJsonFile<T>(filePath: string, normalize: (parsed: Partial<T>) => T): T | null {
  if (!fs.existsSync(filePath)) return null;
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as Partial<T>;
    return normalize(parsed);
  } catch {
    return null;
  }
}

export function emptyStoreTrackEvidence(): StoreTrackEvidence {
  return {
    success: false,
    build_uploaded: false,
    build_installed: false,
    onboarding_completed: false,
    record_completed: false,
    archive_viewed: false,
    purchase_completed: false,
    restore_completed: false,
    timestamp: "",
  };
}

export function readTestflightEvidence(): StoreTrackEvidence | null {
  return readJsonFile<StoreTrackEvidence>(TESTFLIGHT_EVIDENCE_PATH, (parsed) => ({
    success: parsed.success === true,
    build_uploaded: parsed.build_uploaded === true,
    build_installed: parsed.build_installed === true,
    onboarding_completed: parsed.onboarding_completed === true,
    record_completed: parsed.record_completed === true,
    archive_viewed: parsed.archive_viewed === true,
    purchase_completed: parsed.purchase_completed === true,
    restore_completed: parsed.restore_completed === true,
    timestamp: typeof parsed.timestamp === "string" ? parsed.timestamp : "",
  }));
}

export function readPlayInternalEvidence(): StoreTrackEvidence | null {
  return readJsonFile<StoreTrackEvidence>(PLAY_INTERNAL_EVIDENCE_PATH, (parsed) => ({
    success: parsed.success === true,
    build_uploaded: parsed.build_uploaded === true,
    build_installed: parsed.build_installed === true,
    onboarding_completed: parsed.onboarding_completed === true,
    record_completed: parsed.record_completed === true,
    archive_viewed: parsed.archive_viewed === true,
    purchase_completed: parsed.purchase_completed === true,
    restore_completed: parsed.restore_completed === true,
    timestamp: typeof parsed.timestamp === "string" ? parsed.timestamp : "",
  }));
}

export function emptyIosSigningEvidence(): IosSigningEvidence {
  return {
    success: false,
    archive_build_created: false,
    uploaded_to_app_store_connect: false,
    timestamp: "",
  };
}

export function readIosSigningEvidence(): IosSigningEvidence | null {
  return readJsonFile<IosSigningEvidence>(IOS_SIGNING_EVIDENCE_PATH, (parsed) => ({
    success: parsed.success === true,
    archive_build_created: parsed.archive_build_created === true,
    uploaded_to_app_store_connect: parsed.uploaded_to_app_store_connect === true,
    timestamp: typeof parsed.timestamp === "string" ? parsed.timestamp : "",
  }));
}

export function emptyAndroidSigningEvidence(): AndroidSigningEvidence {
  return {
    success: false,
    signed_aab_created: false,
    uploaded_to_play_console: false,
    timestamp: "",
  };
}

export function readAndroidSigningEvidence(): AndroidSigningEvidence | null {
  return readJsonFile<AndroidSigningEvidence>(ANDROID_SIGNING_EVIDENCE_PATH, (parsed) => ({
    success: parsed.success === true,
    signed_aab_created: parsed.signed_aab_created === true,
    uploaded_to_play_console: parsed.uploaded_to_play_console === true,
    timestamp: typeof parsed.timestamp === "string" ? parsed.timestamp : "",
  }));
}

function trackMissingRequirements(
  evidence: StoreTrackEvidence | null,
  relPath: string,
): string[] {
  if (!evidence) {
    return [`missing ${relPath}`];
  }
  const missing: string[] = [];
  for (const field of TRACK_BOOLEAN_FIELDS) {
    if (!evidence[field]) missing.push(field);
  }
  if (!evidence.timestamp) missing.push("timestamp");
  return missing;
}

export function testflightProofMissingRequirements(
  evidence: StoreTrackEvidence | null = readTestflightEvidence(),
): string[] {
  return trackMissingRequirements(evidence, "mobile/evidence/testflight_tested.json");
}

export function playProofMissingRequirements(
  evidence: StoreTrackEvidence | null = readPlayInternalEvidence(),
): string[] {
  return trackMissingRequirements(evidence, "mobile/evidence/play_internal_tested.json");
}

export function iosSigningMissingRequirements(
  evidence: IosSigningEvidence | null = readIosSigningEvidence(),
): string[] {
  if (!evidence) {
    return ["missing mobile/evidence/ios_signing_tested.json"];
  }
  const missing: string[] = [];
  if (!evidence.success) missing.push("success");
  if (!evidence.archive_build_created) missing.push("archive_build_created");
  if (!evidence.uploaded_to_app_store_connect) missing.push("uploaded_to_app_store_connect");
  if (!evidence.timestamp) missing.push("timestamp");
  return missing;
}

export function androidSigningMissingRequirements(
  evidence: AndroidSigningEvidence | null = readAndroidSigningEvidence(),
): string[] {
  if (!evidence) {
    return ["missing mobile/evidence/android_signing_tested.json"];
  }
  const missing: string[] = [];
  if (!evidence.success) missing.push("success");
  if (!evidence.signed_aab_created) missing.push("signed_aab_created");
  if (!evidence.uploaded_to_play_console) missing.push("uploaded_to_play_console");
  if (!evidence.timestamp) missing.push("timestamp");
  return missing;
}

export function isTestflightProofPassing(
  evidence: StoreTrackEvidence | null = readTestflightEvidence(),
): boolean {
  return testflightProofMissingRequirements(evidence).length === 0;
}

export function isPlayProofPassing(
  evidence: StoreTrackEvidence | null = readPlayInternalEvidence(),
): boolean {
  return playProofMissingRequirements(evidence).length === 0;
}

export function isIosSigningPassing(
  evidence: IosSigningEvidence | null = readIosSigningEvidence(),
): boolean {
  return iosSigningMissingRequirements(evidence).length === 0;
}

export function isAndroidSigningPassing(
  evidence: AndroidSigningEvidence | null = readAndroidSigningEvidence(),
): boolean {
  return androidSigningMissingRequirements(evidence).length === 0;
}

function resolvePillarStatus(
  fileExists: boolean,
  passing: boolean,
): StoreReadinessStatus {
  if (passing) return "PASSING";
  if (!fileExists) return "UNKNOWN";
  return "FAILING";
}

function buildPillar(
  id: StoreDistributionPillarId,
  label: string,
  evidenceFiles: string[],
  fileExists: boolean,
  passing: boolean,
  missingRequirements: string[],
): StoreDistributionPillarRow {
  return {
    id,
    label,
    status: resolvePillarStatus(fileExists, passing),
    evidenceFiles,
    missingRequirements,
  };
}

function sectionVerdict(pillars: StoreDistributionPillarRow[]): StoreReadinessStatus {
  if (pillars.every((p) => p.status === "PASSING")) return "PASSING";
  if (pillars.some((p) => p.status === "FAILING")) return "FAILING";
  return "UNKNOWN";
}

function buildIosSection(): StorePlatformDistributionSection {
  const track = readTestflightEvidence();
  const signing = readIosSigningEvidence();
  const trackExists = fs.existsSync(TESTFLIGHT_EVIDENCE_PATH);
  const signingExists = fs.existsSync(IOS_SIGNING_EVIDENCE_PATH);

  const pillars: StoreDistributionPillarRow[] = [
    buildPillar(
      "signing",
      "Signing",
      ["mobile/evidence/ios_signing_tested.json"],
      signingExists,
      isIosSigningPassing(signing),
      iosSigningMissingRequirements(signing),
    ),
    buildPillar(
      "store_upload",
      "Store Upload",
      ["mobile/evidence/testflight_tested.json"],
      trackExists,
      track?.build_uploaded === true,
      track?.build_uploaded ? [] : ["build_uploaded"],
    ),
    buildPillar(
      "install",
      "Install",
      ["mobile/evidence/testflight_tested.json"],
      trackExists,
      track?.build_installed === true,
      track?.build_installed ? [] : ["build_installed"],
    ),
    buildPillar(
      "purchase",
      "Purchase",
      ["mobile/evidence/testflight_tested.json"],
      trackExists,
      track?.purchase_completed === true,
      track?.purchase_completed ? [] : ["purchase_completed"],
    ),
    buildPillar(
      "restore",
      "Restore",
      ["mobile/evidence/testflight_tested.json"],
      trackExists,
      track?.restore_completed === true,
      track?.restore_completed ? [] : ["restore_completed"],
    ),
  ];

  return { platform: "ios", pillars, verdict: sectionVerdict(pillars) };
}

function buildAndroidSection(): StorePlatformDistributionSection {
  const track = readPlayInternalEvidence();
  const signing = readAndroidSigningEvidence();
  const trackExists = fs.existsSync(PLAY_INTERNAL_EVIDENCE_PATH);
  const signingExists = fs.existsSync(ANDROID_SIGNING_EVIDENCE_PATH);

  const pillars: StoreDistributionPillarRow[] = [
    buildPillar(
      "signing",
      "Signing",
      ["mobile/evidence/android_signing_tested.json"],
      signingExists,
      isAndroidSigningPassing(signing),
      androidSigningMissingRequirements(signing),
    ),
    buildPillar(
      "store_upload",
      "Store Upload",
      ["mobile/evidence/play_internal_tested.json"],
      trackExists,
      track?.build_uploaded === true,
      track?.build_uploaded ? [] : ["build_uploaded"],
    ),
    buildPillar(
      "install",
      "Install",
      ["mobile/evidence/play_internal_tested.json"],
      trackExists,
      track?.build_installed === true,
      track?.build_installed ? [] : ["build_installed"],
    ),
    buildPillar(
      "purchase",
      "Purchase",
      ["mobile/evidence/play_internal_tested.json"],
      trackExists,
      track?.purchase_completed === true,
      track?.purchase_completed ? [] : ["purchase_completed"],
    ),
    buildPillar(
      "restore",
      "Restore",
      ["mobile/evidence/play_internal_tested.json"],
      trackExists,
      track?.restore_completed === true,
      track?.restore_completed ? [] : ["restore_completed"],
    ),
  ];

  return { platform: "android", pillars, verdict: sectionVerdict(pillars) };
}

export function buildStoreDistributionReadinessReport(): StoreDistributionReadinessReport {
  return {
    generatedAt: new Date().toISOString(),
    ios: buildIosSection(),
    android: buildAndroidSection(),
    testflightProofPassing: isTestflightProofPassing(),
    playProofPassing: isPlayProofPassing(),
    iosSigningPassing: isIosSigningPassing(),
    androidSigningPassing: isAndroidSigningPassing(),
  };
}
