/** Push Notification Verification v1 — prove delivery and open path. */

export type PushVerificationCheckId =
  | "permission_requested"
  | "permission_granted"
  | "notification_delivered"
  | "notification_tapped"
  | "correct_screen_opened";

export type PushVerificationCheckStatus = "UNKNOWN" | "FAILING" | "PASSING";

export type PushVerificationEvent = {
  id: string;
  at: string;
  title: string;
  targetPath: string;
  tag: string;
};

export type PushVerificationScreenEvent = {
  at: string;
  path: string;
  targetPath: string;
  matchesTarget: boolean;
};

export type PushVerificationStore = {
  permissionRequestedAt: string | null;
  permissionGrantedAt: string | null;
  permissionDeniedAt: string | null;
  lastNotificationSent: PushVerificationEvent | null;
  lastNotificationDelivered: PushVerificationEvent | null;
  lastNotificationOpened: PushVerificationEvent | null;
  lastScreenOpened: PushVerificationScreenEvent | null;
};

export type PushVerificationCheck = {
  id: PushVerificationCheckId;
  label: string;
  status: PushVerificationCheckStatus;
  detail: string;
};

export type PushVerificationReport = {
  generatedAt: string;
  store: PushVerificationStore;
  checks: PushVerificationCheck[];
  permission: NotificationPermission | "unsupported" | "unavailable";
  pushApiAvailable: boolean;
  unknownCount: number;
  passingCount: number;
  failingCount: number;
};
