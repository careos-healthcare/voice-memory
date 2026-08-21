"use client";

import { useEffect, useState } from "react";

import { runWhenIdle } from "@/lib/open-loops/open-loop-defer";
import { recoverPendingDrafts } from "@/lib/reliability/draft-recovery";
import { DRAFT_RECOVERED_COPY } from "@/lib/reliability/copy";
import { ensureJournalPersistence } from "@/lib/persistence/journal-store";
import { ensureStorageReady } from "@/lib/reliability/migrations";
import { ensureCaptureAttested } from "@/lib/client/capture-attest";

export function StorageBootstrap() {
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    const cancel = runWhenIdle(() => {
      ensureStorageReady();
      void ensureJournalPersistence();
      void ensureCaptureAttested();
      void import("@/lib/entitlement/entitlements").then((mod) => {
        void mod.refreshServerEntitlements();
      });
      void import("@/lib/persistence/journal-sync-engine").then(async (sync) => {
        const signedIn = await sync.hasSignedInSession();
        if (!signedIn) return;
        const { exportJournalSnapshot } = await import("@/lib/persistence/journal-store");
        const local = await exportJournalSnapshot();
        const merged = await sync.reconcileJournalWithServer(local);
        if (merged.length > 0) {
          const { getAllEntries } = await import("@/lib/storage");
          const current = getAllEntries();
          if (merged.length !== current.length) {
            const { safeSetJson } = await import("@/lib/reliability/safe-local-storage");
            safeSetJson("voicememory_entries", merged);
          }
        }
        void sync.flushJournalSyncQueue();
      });
      const { recovered } = recoverPendingDrafts();
      if (recovered > 0) {
        setNotice(DRAFT_RECOVERED_COPY);
      }
    });
    return cancel;
  }, []);

  if (!notice) return null;

  return (
    <div
      role="status"
      className="fixed bottom-[max(1rem,env(safe-area-inset-bottom))] left-1/2 z-50 max-w-sm -translate-x-1/2 rounded-xl border border-zinc-700/80 bg-zinc-900/95 px-4 py-3 text-center text-sm text-zinc-300 shadow-lg"
    >
      {notice}
    </div>
  );
}
