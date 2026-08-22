import "server-only";

/**
 * INTERNAL telemetry for curiosity loop scheduling — never imported by public routes.
 * @module src/internal/loops/telemetry/curiosity_loop_telemetry
 */

export type CuriosityLoopTelemetryEvent =
  | "hook_scheduled"
  | "hook_dispatch_cancelled"
  | "hook_dispatch_sent"
  | "hook_dispatch_failed";

export interface CuriosityLoopTelemetryPayload {
  userHash?: string;
  hookId?: string;
  queueId?: string;
  reason?: string;
  scheduleAfterMinutes?: number;
}

export function emitCuriosityLoopTelemetry(
  event: CuriosityLoopTelemetryEvent,
  payload: CuriosityLoopTelemetryPayload = {},
): void {
  if (process.env.NODE_ENV === "test") return;

  console.info(
    JSON.stringify({
      ts: new Date().toISOString(),
      component: "curiosity_loop_telemetry",
      event,
      ...payload,
    }),
  );
}
