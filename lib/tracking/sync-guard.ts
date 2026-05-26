/** Prevent synchronous tracking chains from re-entering analytics / learning writes. */

const MAX_DEPTH = 6;
let depth = 0;

export function isTrackingReentrant(): boolean {
  return depth >= MAX_DEPTH;
}

export function withTrackingGuard<T>(run: () => T): T | undefined {
  if (depth >= MAX_DEPTH) return undefined;
  depth += 1;
  try {
    return run();
  } finally {
    depth -= 1;
  }
}
