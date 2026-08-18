import type { ReflexTriggerType } from "@/types/reflex";

export const REFLEX_CAPTURE_KEY = "voicememory_reflex_capture";

export interface ReflexCaptureContext {
  continuityLine: string;
  triggerType: ReflexTriggerType;
  anchorQuote: string | null;
  noteId: string | null;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function storeReflexCaptureContext(context: ReflexCaptureContext): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(REFLEX_CAPTURE_KEY, JSON.stringify(context));
}

export function peekReflexCaptureContext(): ReflexCaptureContext | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(REFLEX_CAPTURE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as ReflexCaptureContext;
  } catch {
    return null;
  }
}

export function consumeReflexCaptureContext(): ReflexCaptureContext | null {
  const ctx = peekReflexCaptureContext();
  if (!ctx || !isBrowser()) return ctx;
  sessionStorage.removeItem(REFLEX_CAPTURE_KEY);
  return ctx;
}
