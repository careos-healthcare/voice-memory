import { hasEntitlement } from "@/lib/entitlement/entitlements";

let timer: number | null = null;

/** Debounced encrypted sync after local writes — Pro + signed in only. */
export function scheduleEncryptedSync(): void {
  if (typeof window === "undefined") return;
  if (!hasEntitlement("encrypted_backup")) return;
  if (timer) window.clearTimeout(timer);
  timer = window.setTimeout(() => {
    void import("@/lib/sync/client").then((mod) => mod.syncArchiveIfSignedIn());
  }, 8000);
}
