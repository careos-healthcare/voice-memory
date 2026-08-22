import { isPresentationBuildActive } from "@/lib/tracking/presentation-guard";

let readOnlyDepth = 0;

export function isReadOnlyPhase(): boolean {
  return readOnlyDepth > 0 || isPresentationBuildActive();
}

/** Run selector/read-model work — no storage writes or analytics. */
export function runReadOnly<T>(label: string, fn: () => T): T {
  readOnlyDepth += 1;
  try {
    return fn();
  } finally {
    readOnlyDepth -= 1;
    if (process.env.NODE_ENV !== "production" && readOnlyDepth < 0) {
      console.warn(`[render-safe] read-only depth underflow after ${label}`);
    }
  }
}

export function assertWriteAllowed(source: string): void {
  if (!isReadOnlyPhase()) return;
  const message = `[render-safe] Write blocked during read-only phase: ${source}`;
  if (process.env.NODE_ENV === "production") {
    console.error(message);
    return;
  }
  throw new Error(message);
}

/** Explicit user action or deferred job — may touch storage and analytics. */
export function runWriteAction<T>(source: string, fn: () => T): T {
  assertWriteAllowed(source);
  return fn();
}
