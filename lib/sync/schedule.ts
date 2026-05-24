let timer: number | null = null;

/** Debounced encrypted sync after local writes — no-op when signed out. */
export function scheduleEncryptedSync(): void {
  if (typeof window === "undefined") return;
  if (timer) window.clearTimeout(timer);
  timer = window.setTimeout(() => {
    void import("@/lib/sync/client").then((mod) => mod.syncArchiveIfSignedIn());
  }, 8000);
}
