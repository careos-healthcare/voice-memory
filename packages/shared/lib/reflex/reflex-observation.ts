import { trackLocalEvent } from "@/lib/local-analytics";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import { withTrackingGuard } from "@/lib/tracking/sync-guard";

export const REFLEX_EVENTS = {
  reflexMomentDetected: "reflex_moment_detected",
  directToMicBypass: "reflex_direct_to_mic_bypass",
  recorderBootMs: "reflex_recorder_boot_ms",
  recordingStartedLatency: "reflex_recording_started_latency",
  silenceFirstActivated: "reflex_silence_first_activated",
  readBeforeSpeak: "reflex_read_before_speak",
  quickEntryOpened: "reflex_quick_entry_opened",
} as const;

export function trackReflexEvent(
  name: (typeof REFLEX_EVENTS)[keyof typeof REFLEX_EVENTS],
  meta?: Record<string, string>,
): void {
  if (typeof window === "undefined" || isSideEffectBlocked()) return;
  withTrackingGuard(() => trackLocalEvent(name, meta));
}

export function markReflexPageLand(): void {
  if (typeof window === "undefined") return;
  sessionStorage.setItem("voicememory_reflex_page_land_at", String(Date.now()));
}

export function markReflexRecorderMounted(): void {
  if (typeof window === "undefined") return;
  const land = Number(sessionStorage.getItem("voicememory_reflex_page_land_at") ?? "0");
  const now = Date.now();
  sessionStorage.setItem("voicememory_reflex_recorder_mount_at", String(now));
  if (land > 0) {
    trackReflexEvent(REFLEX_EVENTS.recorderBootMs, {
      ms: String(now - land),
    });
  }
}

export function markReflexRecordingStarted(): void {
  if (typeof window === "undefined") return;
  const mount = Number(sessionStorage.getItem("voicememory_reflex_recorder_mount_at") ?? "0");
  const land = Number(sessionStorage.getItem("voicememory_reflex_page_land_at") ?? "0");
  const now = Date.now();
  if (mount > 0) {
    trackReflexEvent(REFLEX_EVENTS.recordingStartedLatency, {
      tapToRecordMs: String(now - mount),
    });
  }
  if (land > 0) {
    trackReflexEvent(REFLEX_EVENTS.recordingStartedLatency, {
      landToRecordMs: String(now - land),
    });
  }
}
