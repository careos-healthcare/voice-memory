/** Mobile FCM device registration + test push. */

export type MobilePushPlatform = "ios" | "android";

export type MobilePushDeviceRow = {
  userId: string;
  deviceId: string;
  platform: MobilePushPlatform;
  fcmToken: string;
  createdAt: string;
  updatedAt: string;
};

export type TestPushTargetRoute = "/archive-belief" | "/discover" | "/record";

export const TEST_PUSH_TARGET_ROUTES: readonly TestPushTargetRoute[] = [
  "/archive-belief",
  "/discover",
  "/record",
] as const;

export type SendTestPushRequest = {
  deviceId: string;
  targetRoute: TestPushTargetRoute;
};

export type RegisterPushDeviceRequest = {
  deviceId: string;
  platform: MobilePushPlatform;
  fcmToken: string;
};
