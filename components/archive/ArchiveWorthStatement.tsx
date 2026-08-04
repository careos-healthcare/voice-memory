"use client";

import Link from "next/link";

import { useAuthPrompt } from "@/components/auth/AuthPromptProvider";
import { useAccount } from "@/components/providers/AccountProvider";
import { buildArchiveWorthSnapshot } from "@/lib/archive/archive-worth";
import { trackProtectArchiveClicked } from "@/lib/auth/guest-first-auth";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveWorthCtaId } from "@/types/archive-worth";
import type { JournalEntry } from "@/types/journal";

interface ArchiveWorthStatementProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  compact?: boolean;
  showCtas?: boolean;
}

const CTA_LABELS: Record<ArchiveWorthCtaId, { label: string; href?: string }> = {
  protect_archive: { label: "Protect this archive" },
  export_archive: { label: "Export archive", href: "/export" },
  pro_continuity: { label: "Keep tracking with Pro", href: "/pricing" },
};

export function ArchiveWorthStatement({
  className = "",
  entriesOverride,
  compact = false,
  showCtas = true,
}: ArchiveWorthStatementProps) {
  const hydrated = useClientHydrated();
  const { requestAuth } = useAuthPrompt();
  const { status } = useAccount();
  const isSignedIn = Boolean(status.session);

  if (!hydrated) return null;

  const snapshot = buildArchiveWorthSnapshot(entriesOverride, { isSignedIn });
  if (!snapshot) return null;

  const handleProtect = () => {
    trackProtectArchiveClicked();
    requestAuth("protect_archive");
  };

  return (
    <section
      className={`rounded-2xl border border-violet-500/25 bg-violet-950/15 px-4 py-4 ${className}`}
      data-testid="archive-worth-statement"
    >
      <p className="text-xs uppercase tracking-[0.16em] text-violet-300/80">Archive worth</p>
      <p className="mt-2 text-sm font-medium text-zinc-100">{snapshot.headline}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{snapshot.summaryLine}</p>

      {!compact ? (
        <ul className="mt-3 grid gap-1 text-xs text-zinc-500 sm:grid-cols-2">
          {snapshot.firstReflectionDateLabel ? (
            <li>First moment: {snapshot.firstReflectionDateLabel}</li>
          ) : null}
          <li>{snapshot.beliefChangesRecorded} belief changes recorded</li>
          {snapshot.strongestRememberedBelief ? (
            <li className="sm:col-span-2">
              Strongest remembered belief:{" "}
              <span className="text-zinc-400">{snapshot.strongestRememberedBelief}</span>
            </li>
          ) : null}
        </ul>
      ) : null}

      {showCtas && snapshot.suggestedCtas.length > 0 ? (
        <div className="mt-4 flex flex-wrap gap-2">
          {snapshot.suggestedCtas.map((cta) => {
            if (cta === "protect_archive" && !isSignedIn) {
              return (
                <button
                  key={cta}
                  type="button"
                  onClick={handleProtect}
                  className="inline-flex min-h-10 items-center rounded-full bg-violet-600/80 px-4 text-sm font-medium text-white hover:bg-violet-600"
                >
                  {CTA_LABELS[cta].label}
                </button>
              );
            }
            const meta = CTA_LABELS[cta];
            if (!meta.href) return null;
            return (
              <Link
                key={cta}
                href={meta.href}
                className="inline-flex min-h-10 items-center rounded-full border border-white/10 px-4 text-sm text-zinc-200 hover:bg-white/5"
              >
                {meta.label}
              </Link>
            );
          })}
        </div>
      ) : null}
    </section>
  );
}
