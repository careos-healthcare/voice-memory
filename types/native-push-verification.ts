/** Native mobile push verification v2 — physical iOS/Android, backend FCM only. */

export type NativePushDeviceType = "ios" | "android";

export type NativePushPlatformEvidence = {
  permission_granted: boolean;
  notification_received: boolean;
  notification_opened: boolean;
  archive_destination_verified: boolean;
  discover_destination_verified: boolean;
  record_destination_verified: boolean;
  timestamp: string;
};

export type NativePushVerificationEvidence = {
  ios: NativePushPlatformEvidence;
  android: NativePushPlatformEvidence;
};

export const NATIVE_PUSH_ROUTES = {
  archive: "/archive-belief",
  discover: "/discover",
  record: "/record",
} as const;

export type NativePushPlatformStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type NativePushPlatformReport = {
  platform: NativePushDeviceType;
  status: NativePushPlatformStatus;
  evidence: NativePushPlatformEvidence;
  missingSteps: string[];
  destinationGaps: string[];
};

export type NativePushReadinessReport = {
  generatedAt: string;
  evidence: NativePushVerificationEvidence | null;
  evidencePath: string;
  ios: NativePushPlatformReport;
  android: NativePushPlatformReport;
  webVerificationExcluded: boolean;
  fcmProductionOnly: boolean;
};
