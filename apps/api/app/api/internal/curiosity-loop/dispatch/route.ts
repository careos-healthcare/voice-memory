import { NextResponse, type NextRequest } from "next/server";

import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { dispatchDueCuriosityNotifications } from "@/src/services/loops/curiosity_notification_scheduler";
import { emitCuriosityLoopTelemetry } from "@/src/internal/loops/telemetry/curiosity_loop_telemetry";

export const runtime = "nodejs";

/** Cron/internal entry — dispatches due evidence-backed curiosity push notifications. */
export async function POST(request: NextRequest) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;

  try {
    const result = await dispatchDueCuriosityNotifications();
    emitCuriosityLoopTelemetry("hook_dispatch_sent", {
      reason: `processed=${result.processed};sent=${result.sent};cancelled=${result.cancelled};failed=${result.failed}`,
    });
    return NextResponse.json({ ok: true, ...result });
  } catch (error) {
    console.error("[internal/curiosity-loop/dispatch]", error);
    emitCuriosityLoopTelemetry("hook_dispatch_failed", {
      reason: error instanceof Error ? error.message : "dispatch_failed",
    });
    return apiErrorFromException(error, {
      code: "CURIOSITY_DISPATCH_FAILED",
      route: "internal/curiosity-loop/dispatch",
      logEvent: "api_error",
    });
  }
}
