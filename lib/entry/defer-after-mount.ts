/** Schedule work after first paint — requestIdleCallback with setTimeout fallback. */

export function scheduleAfterMount(
  run: () => void,
  options?: { timeoutMs?: number; delayMs?: number },
): () => void {
  let cancelled = false;
  const invoke = () => {
    if (!cancelled) run();
  };

  if (typeof window === "undefined") {
    return () => {
      cancelled = true;
    };
  }

  const delayMs = options?.delayMs ?? 0;
  const idleTimeout = options?.timeoutMs ?? 1200;

  const start = () => {
    if (typeof requestIdleCallback === "function") {
      const id = requestIdleCallback(invoke, { timeout: idleTimeout });
      return () => cancelIdleCallback(id);
    }
    const timer = window.setTimeout(invoke, 0);
    return () => window.clearTimeout(timer);
  };

  let cancelInner: (() => void) | undefined;
  const outer =
    delayMs > 0
      ? window.setTimeout(() => {
          if (cancelled) return;
          cancelInner = start();
        }, delayMs)
      : undefined;

  if (delayMs <= 0) {
    cancelInner = start();
  }

  return () => {
    cancelled = true;
    if (outer !== undefined) window.clearTimeout(outer);
    cancelInner?.();
  };
}
