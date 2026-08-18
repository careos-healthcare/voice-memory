import { recordDeferredTaskDuration } from "@/lib/open-loops/open-loop-performance";

export function runWhenIdle(task: () => void, timeoutMs = 2000): () => void {
  if (typeof window === "undefined") {
    const started = performance.now();
    task();
    recordDeferredTaskDuration(performance.now() - started);
    return () => {};
  }

  const started = performance.now();
  const finish = () => {
    recordDeferredTaskDuration(performance.now() - started);
  };

  if (typeof requestIdleCallback === "function") {
    const id = requestIdleCallback(
      () => {
        task();
        finish();
      },
      { timeout: timeoutMs },
    );
    return () => cancelIdleCallback(id);
  }

  const id = window.setTimeout(() => {
    task();
    finish();
  }, 0);
  return () => clearTimeout(id);
}
