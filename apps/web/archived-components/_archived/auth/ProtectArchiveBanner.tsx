"use client";

import { useEffect, useRef } from "react";

import { useAuthPrompt } from "@/archived-components/_archived/auth/AuthPromptProvider";
import { useAccount } from "@/components/providers/AccountProvider";
import {
  dismissProtectArchiveBanner,
  shouldShowProtectArchiveBanner,
  trackProtectArchiveBannerSeen,
  trackProtectArchiveClicked,
} from "@/lib/auth/guest-first-auth";

export function ProtectArchiveBanner() {
  const { status } = useAccount();
  const { requestAuth } = useAuthPrompt();
  const seenRef = useRef(false);

  const show = shouldShowProtectArchiveBanner(Boolean(status.session));

  useEffect(() => {
    if (!show || seenRef.current) return;
    seenRef.current = true;
    trackProtectArchiveBannerSeen();
  }, [show]);

  if (!show) return null;

  return (
    <div
      className="rounded-xl border border-violet-500/20 bg-violet-950/20 px-4 py-3"
      data-testid="protect-archive-banner"
    >
      <p className="text-sm text-zinc-300">Protect this archive with email sign-in.</p>
      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          className="rounded-lg bg-violet-600/90 px-3 py-1.5 text-sm font-medium text-white hover:bg-violet-500"
          onClick={() => {
            trackProtectArchiveClicked();
            requestAuth("protect_archive");
          }}
        >
          Protect archive
        </button>
        <button
          type="button"
          className="rounded-lg px-3 py-1.5 text-sm text-zinc-500 hover:text-zinc-300"
          onClick={() => dismissProtectArchiveBanner()}
        >
          Dismiss
        </button>
      </div>
    </div>
  );
}
