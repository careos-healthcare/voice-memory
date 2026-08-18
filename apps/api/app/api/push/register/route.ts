import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import {
  pruneStaleMobilePushDevices,
  resolvePushUserId,
  upsertMobilePushDevice,
} from "@/lib/push/mobile-push-devices";
import { getServerSession } from "@/lib/server/session";
import type { MobilePushPlatform, RegisterPushDeviceRequest } from "@/types/mobile-push";

export const runtime = "nodejs";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isPlatform(value: string): value is MobilePushPlatform {
  return value === "ios" || value === "android";
}

/** Register or refresh FCM token for a physical device. */
export async function POST(request: Request) {
  let body: RegisterPushDeviceRequest;
  try {
    body = (await request.json()) as RegisterPushDeviceRequest;
  } catch {
    return apiErrorResponse({
      code: "PUSH_INVALID_JSON",
      route: "push/register",
      internalCategory: "validation",
    });
  }

  const deviceId = body.deviceId?.trim();
  const platform = body.platform?.trim();
  const fcmToken = body.fcmToken?.trim();

  if (!deviceId || !UUID_RE.test(deviceId)) {
    return apiErrorResponse({ code: "PUSH_INVALID_DEVICE", route: "push/register" });
  }
  if (!platform || !isPlatform(platform)) {
    return apiErrorResponse({ code: "PUSH_INVALID_PLATFORM", route: "push/register" });
  }
  if (!fcmToken || fcmToken.length < 20) {
    return apiErrorResponse({ code: "PUSH_INVALID_TOKEN", route: "push/register" });
  }

  const session = await getServerSession();
  const userId = resolvePushUserId(session?.userId ?? null, deviceId);

  try {
    await upsertMobilePushDevice({ userId, deviceId, platform, fcmToken });
    const pruned = await pruneStaleMobilePushDevices();
    return NextResponse.json({ ok: true, userId, pruned });
  } catch (err) {
    console.error("[push/register]", err);
    return apiErrorFromException(err, {
      code: "PUSH_REGISTRATION_FAILED",
      route: "push/register",
      logEvent: "api_error",
    });
  }
}
