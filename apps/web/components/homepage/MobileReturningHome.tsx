"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { useMemo, type ReactNode } from "react";

import { FirstReturnMoment } from "@/components/continuity/FirstReturnMoment";
import { ReturnThreadCard } from "@/components/continuity/ReturnThreadCard";
import { pickFirstReturnMoment } from "@/lib/continuity/first-return-moment";
import { HabitLoopCard } from "@/components/HabitLoopCard";
import { EntryListRowMeta } from "@/components/memory/EntryListRowMeta";
import { pickMobileHomeSecondary } from "@/lib/mobile/homepage-mobile-compression";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { getMemoryEligibleEntries } from "@/lib/storage";

export function MobileReturningHome({
  continuityLine,
  recorder,
}: {
  continuityLine: string | null;
  recorder: ReactNode;
}) {
  const entries = useMemo(() => getMemoryEligibleEntries(), []);
  const returnMoment = useMemo(() => pickFirstReturnMoment(entries), [entries]);
  const secondary = useMemo(
    () => (returnMoment ? null : pickMobileHomeSecondary(entries)),
    [entries, returnMoment],
  );
  const showRhythm = countCompletedReflections() >= 2 && !returnMoment;

  return (
    <div className="flex w-full max-w-md flex-col items-center text-center">
      {returnMoment ? (
        <div className="mb-8 w-full">
          <FirstReturnMoment
            entries={entries}
            presentation="quiet"
            trackShown
          />
        </div>
      ) : continuityLine ? (
        <p className="mb-6 max-w-sm text-sm leading-[1.75] text-zinc-400/95">
          {continuityLine}
        </p>
      ) : null}

      <div className="w-full">{recorder}</div>

      {!returnMoment && secondary?.kind === "return_thread" && secondary.thread ? (
        <div className="mt-8 w-full text-left">
          <ReturnThreadCard thread={secondary.thread} />
        </div>
      ) : !returnMoment && secondary?.kind === "latest_reflection" && secondary.entry ? (
        <Link
          href={`/entry/${secondary.entry.id}`}
          className="group mt-8 block w-full rounded-2xl border border-white/10 bg-white/[0.02] p-4 text-left transition-colors hover:border-violet-400/25"
        >
          <EntryListRowMeta createdAt={secondary.entry.createdAt} />
          <p className="mt-2 line-clamp-1 text-xs leading-relaxed text-zinc-500">
            {secondary.snippet}
          </p>
          <span className="mt-3 inline-flex items-center gap-1 text-xs text-zinc-600 group-hover:text-violet-300">
            Open last reflection
            <ArrowRight className="h-3.5 w-3.5" />
          </span>
        </Link>
      ) : null}

      {showRhythm ? (
        <div className="mt-10 w-full text-left">
          <HabitLoopCard compact suppressRecordCta />
        </div>
      ) : null}
    </div>
  );
}
