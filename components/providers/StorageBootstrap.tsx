"use client";

import { useEffect, useState } from "react";

import { recoverPendingDrafts } from "@/lib/reliability/draft-recovery";
import { DRAFT_RECOVERED_COPY } from "@/lib/reliability/copy";
import { ensureStorageReady } from "@/lib/reliability/migrations";

export function StorageBootstrap() {
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    ensureStorageReady();
    const { recovered } = recoverPendingDrafts();
    if (recovered > 0) {
      setNotice(DRAFT_RECOVERED_COPY);
    }
  }, []);

  if (!notice) return null;

  return (
    <div
      role="status"
      className="fixed bottom-4 left-1/2 z-50 max-w-sm -translate-x-1/2 rounded-xl border border-zinc-700/80 bg-zinc-900/95 px-4 py-3 text-center text-sm text-zinc-300 shadow-lg"
    >
      {notice}
    </div>
  );
}
