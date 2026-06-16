import { NextResponse, type NextRequest } from "next/server";

import { isFcmConfigured, isStaleTokenError, sendFcmTestPush } from "@/lib/push/fcm-admin";
import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import {
  getFcmTokenForDevice,
  pruneStaleMobilePushDevices,
  removeMobilePushDevice,
} from "@/lib/push/mobile-push-devices";
import {
  TEST_PUSH_TARGET_ROUTES,
  type SendTestPushRequest,
  type TestPushTargetRoute,
} from "@/types/mobile-push";

export const runtime = "nodejs";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Send a real FCM test push to a registered device — founder/debug token only. */
export async function POST(request: NextRequest) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;

  if (!isFcmConfigured()) {
    return NextResponse.json(
      {
        error: "FCM not configured",
        code: "FCM_NOT_CONFIGURED",
        hint: "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY",
      },
      { status: 503 },
    );
  }

  let body: SendTestPushRequest;
  try {
    body = (await request.json()) as SendTestPushRequest;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const deviceId = body.deviceId?.trim();
  const targetRoute = body.targetRoute?.trim() as TestPushTargetRoute;

  if (!deviceId || !UUID_RE.test(deviceId)) {
    return NextResponse.json({ error: "Valid deviceId required" }, { status: 400 });
  }
  if (!TEST_PUSH_TARGET_ROUTES.includes(targetRoute)) {
    return NextResponse.json(
      { error: "targetRoute must be /archive-belief, /discover, or /record" },
      { status: 400 },
    );
  }

  const token = await getFcmTokenForDevice(deviceId);
  if (!token) {
    return NextResponse.json(
      { error: "Device not registered — open app and grant push permission first", code: "DEVICE_NOT_REGISTERED" },
      { status: 404 },
    );
  }

  try {
    const result = await sendFcmTestPush({ token, targetRoute });
    await pruneStaleMobilePushDevices();
    return NextResponse.json({
      ok: true,
      messageId: result.messageId,
      deviceId,
      targetRoute,
      delivery: "fcm",
    });
  } catch (err) {
    if (isStaleTokenError(err)) {
      await removeMobilePushDevice(deviceId);
      return NextResponse.json(
        { error: "Stale FCM token removed — re-register on device", code: "STALE_TOKEN" },
        { status: 410 },
      );
    }
    console.error("[internal/send-test-push]", err);
    const message = err instanceof Error ? err.message : "Send failed";
    return NextResponse.json({ error: message, code: "FCM_SEND_FAILED" }, { status: 502 });
  }
}
