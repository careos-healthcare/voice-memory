import { NextResponse } from "next/server";

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
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const deviceId = body.deviceId?.trim();
  const platform = body.platform?.trim();
  const fcmToken = body.fcmToken?.trim();

  if (!deviceId || !UUID_RE.test(deviceId)) {
    return NextResponse.json({ error: "Valid deviceId required" }, { status: 400 });
  }
  if (!platform || !isPlatform(platform)) {
    return NextResponse.json({ error: "platform must be ios or android" }, { status: 400 });
  }
  if (!fcmToken || fcmToken.length < 20) {
    return NextResponse.json({ error: "Valid fcmToken required" }, { status: 400 });
  }

  const session = await getServerSession();
  const userId = resolvePushUserId(session?.userId ?? null, deviceId);

  try {
    await upsertMobilePushDevice({ userId, deviceId, platform, fcmToken });
    const pruned = await pruneStaleMobilePushDevices();
    return NextResponse.json({ ok: true, userId, pruned });
  } catch (err) {
    console.error("[push/register]", err);
    return NextResponse.json({ error: "Registration failed" }, { status: 500 });
  }
}
