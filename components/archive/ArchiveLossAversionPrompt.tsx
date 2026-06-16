"use client";

import { useEffect, useState } from "react";

import { useAuthPrompt } from "@/components/auth/AuthPromptProvider";
import { useAccount } from "@/components/providers/AccountProvider";
import {
  canShowArchiveLossPrompt,
  dismissArchiveLossPrompt,
  markArchiveLossPromptShown,
  markFirstWorkingBeliefSeenIfNeeded,
  trackArchiveLossPromptClicked,
} from "@/lib/archive/archive-loss-prompt";
import { trackProtectArchiveClicked } from "@/lib/auth/guest-first-auth";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

interface ArchiveLossAversionPromptProps {
  className?: string;
}

export function ArchiveLossAversionPrompt({ className = "" }: ArchiveLossAversionPromptProps) {
  const hydrated = useClientHydrated();
  const { requestAuth } = useAuthPrompt();
  const { status } = useAccount();
  const isSignedIn = Boolean(status.session);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!hydrated) return;
    markFirstWorkingBeliefSeenIfNeeded();
    if (canShowArchiveLossPrompt(isSignedIn)) {
      markArchiveLossPromptShown();
      setVisible(true);
    }
  }, [hydrated, isSignedIn]);

  if (!visible) return null;

  const protect = () => {
    trackArchiveLossPromptClicked();
    trackProtectArchiveClicked();
    requestAuth("protect_archive");
    setVisible(false);
  };

  const dismiss = () => {
    dismissArchiveLossPrompt();
    setVisible(false);
  };

  return (
    <aside
      className={`rounded-2xl border border-amber-500/25 bg-amber-950/15 px-4 py-4 ${className}`}
      data-testid="archive-loss-prompt"
    >
      <p className="text-sm leading-relaxed text-zinc-300">
        If this device disappeared, this archive would disappear too.
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={protect}
          className="inline-flex min-h-10 items-center rounded-full bg-violet-600/80 px-4 text-sm font-medium text-white hover:bg-violet-600"
        >
          Protect archive
        </button>
        <button
          type="button"
          onClick={dismiss}
          className="inline-flex min-h-10 items-center rounded-full border border-white/10 px-4 text-sm text-zinc-400 hover:bg-white/5"
        >
          Not now
        </button>
      </div>
    </aside>
  );
}
