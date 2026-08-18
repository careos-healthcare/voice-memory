import fs from "node:fs";
import path from "node:path";

import {
  NATIVE_PUSH_ROUTES,
  type NativePushPlatformEvidence,
  type NativePushPlatformReport,
  type NativePushPlatformStatus,
  type NativePushReadinessReport,
  type NativePushVerificationEvidence,
} from "@/types/native-push-verification";

export const NATIVE_PUSH_VERIFICATION_PATH = path.join(
  process.cwd(),
  "mobile",
  "evidence",
  "native_push_verification.json",
);

function emptyPlatformEvidence(): NativePushPlatformEvidence {
  return {
    permission_granted: false,
    notification_received: false,
    notification_opened: false,
    archive_destination_verified: false,
    discover_destination_verified: false,
    record_destination_verified: false,
    timestamp: "",
  };
}

export function emptyNativePushVerificationEvidence(): NativePushVerificationEvidence {
  return {
    ios: emptyPlatformEvidence(),
    android: emptyPlatformEvidence(),
  };
}

/** Migrate v1 destinations_verified[] to v2 boolean flags. */
function normalizePlatformEvidence(
  raw: Record<string, unknown> | undefined,
): NativePushPlatformEvidence {
  if (!raw) return emptyPlatformEvidence();

  const legacy = raw.destinations_verified;
  const legacyRoutes = Array.isArray(legacy) ? legacy.map(String) : [];

  return {
    permission_granted: raw.permission_granted === true,
    notification_received: raw.notification_received === true,
    notification_opened: raw.notification_opened === true,
    archive_destination_verified:
      raw.archive_destination_verified === true ||
      legacyRoutes.includes(NATIVE_PUSH_ROUTES.archive),
    discover_destination_verified:
      raw.discover_destination_verified === true ||
      legacyRoutes.includes(NATIVE_PUSH_ROUTES.discover),
    record_destination_verified:
      raw.record_destination_verified === true ||
      legacyRoutes.includes(NATIVE_PUSH_ROUTES.record),
    timestamp: typeof raw.timestamp === "string" ? raw.timestamp : "",
  };
}

export function readNativePushVerificationEvidence(): NativePushVerificationEvidence | null {
  if (!fs.existsSync(NATIVE_PUSH_VERIFICATION_PATH)) return null;
  try {
    const raw = fs.readFileSync(NATIVE_PUSH_VERIFICATION_PATH, "utf8");
    const parsed = JSON.parse(raw) as {
      ios?: Record<string, unknown>;
      android?: Record<string, unknown>;
    };
    return {
      ios: normalizePlatformEvidence(parsed.ios),
      android: normalizePlatformEvidence(parsed.android),
    };
  } catch {
    return null;
  }
}

function platformPasses(evidence: NativePushPlatformEvidence): boolean {
  return (
    evidence.permission_granted &&
    evidence.notification_received &&
    evidence.notification_opened &&
    evidence.archive_destination_verified &&
    evidence.discover_destination_verified &&
    evidence.record_destination_verified
  );
}

function evaluatePlatform(
  platform: "ios" | "android",
  evidence: NativePushPlatformEvidence | undefined,
): NativePushPlatformReport {
  const row = evidence ?? emptyPlatformEvidence();
  const missingSteps: string[] = [];
  if (!row.permission_granted) missingSteps.push("permission_granted");
  if (!row.notification_received) missingSteps.push("notification_received");
  if (!row.notification_opened) missingSteps.push("notification_opened");

  const destinationGaps: string[] = [];
  if (!row.archive_destination_verified) destinationGaps.push(NATIVE_PUSH_ROUTES.archive);
  if (!row.discover_destination_verified) destinationGaps.push(NATIVE_PUSH_ROUTES.discover);
  if (!row.record_destination_verified) destinationGaps.push(NATIVE_PUSH_ROUTES.record);

  let status: NativePushPlatformStatus = "UNKNOWN";
  if (!evidence) {
    status = "UNKNOWN";
  } else if (platformPasses(row)) {
    status = "PASSING";
  } else {
    status = "FAILING";
  }

  return {
    platform,
    status,
    evidence: row,
    missingSteps,
    destinationGaps,
  };
}

export function buildNativePushReadinessReport(): NativePushReadinessReport {
  const evidence = readNativePushVerificationEvidence();
  return {
    generatedAt: new Date().toISOString(),
    evidence,
    evidencePath: NATIVE_PUSH_VERIFICATION_PATH,
    ios: evaluatePlatform("ios", evidence?.ios),
    android: evaluatePlatform("android", evidence?.android),
    webVerificationExcluded: true,
    fcmProductionOnly: true,
  };
}

export function isNativePushFullyVerified(): boolean {
  const report = buildNativePushReadinessReport();
  return report.ios.status === "PASSING" && report.android.status === "PASSING";
}

export function isPushProductionPassing(): boolean {
  return isNativePushFullyVerified();
}

export function nativePushEvidenceMissingPlatforms(): ("ios" | "android")[] {
  const evidence = readNativePushVerificationEvidence();
  const missing: ("ios" | "android")[] = [];
  if (!evidence) return ["ios", "android"];
  if (!platformPasses(evidence.ios)) missing.push("ios");
  if (!platformPasses(evidence.android)) missing.push("android");
  return [...new Set(missing)];
}
