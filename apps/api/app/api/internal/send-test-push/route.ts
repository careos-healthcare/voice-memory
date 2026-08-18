import { NextResponse, type NextRequest } from "next/server";

import { isFcmConfigured, isStaleTokenError, sendFcmTestPush } from "@/lib/push/fcm-admin";
import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import {
  apiErrorFromException,
  apiErrorResponse,
  buildApiErrorEnvelope,
} from "@/lib/server/api-error-response";
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
    const built = buildApiErrorEnvelope({ code: "FCM_NOT_CONFIGURED", status: 503 });
    return NextResponse.json(
      {
        ...built.body,
        hint: "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY",
      },
      { status: 503 },
    );
  }

  let body: SendTestPushRequest;
  try {
    body = (await request.json()) as SendTestPushRequest;
  } catch {
    return apiErrorResponse({
      code: "PUSH_INVALID_JSON",
      route: "internal/send-test-push",
      internalCategory: "validation",
    });
  }

  const deviceId = body.deviceId?.trim();
  const targetRoute = body.targetRoute?.trim() as TestPushTargetRoute;

  if (!deviceId || !UUID_RE.test(deviceId)) {
    return apiErrorResponse({ code: "PUSH_INVALID_DEVICE", route: "internal/send-test-push" });
  }
  if (!TEST_PUSH_TARGET_ROUTES.includes(targetRoute)) {
    return apiErrorResponse({ code: "PUSH_INVALID_TARGET_ROUTE", route: "internal/send-test-push" });
  }

  const token = await getFcmTokenForDevice(deviceId);
  if (!token) {
    return apiErrorResponse({ code: "DEVICE_NOT_REGISTERED", route: "internal/send-test-push" });
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
      return apiErrorResponse({ code: "STALE_TOKEN", route: "internal/send-test-push" });
    }
    console.error("[internal/send-test-push]", err);
    return apiErrorFromException(err, {
      code: "FCM_SEND_FAILED",
      route: "internal/send-test-push",
      logEvent: "api_error",
    });
  }
}
