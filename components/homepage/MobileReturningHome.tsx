"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { useMemo, type ReactNode } from "react";

import { ReturnThreadCard } from "@/components/continuity/ReturnThreadCard";
import { EntryListRowMeta } from "@/components/memory/EntryListRowMeta";
import { pickMobileHomeSecondary } from "@/lib/mobile/homepage-mobile-compression";
import { getMemoryEligibleEntries } from "@/lib/storage";

export function MobileReturningHome({
  continuityLine,
  recorder,
  rhythm,
}: {
  continuityLine: string | null;
  recorder: ReactNode;
  rhythm: ReactNode;
}) {
  const secondary = useMemo(() => pickMobileHomeSecondary(getMemoryEligibleEntries()), []);

  return (
    <div className="flex w-full max-w-md flex-col items-center text-center">
      {continuityLine ? (
        <p className="mb-6 max-w-sm text-sm leading-[1.75] text-zinc-400/95">{continuityLine}</p>
      ) : null}
      <div className="w-full">{recorder}</div>

      {secondary?.kind === "return_thread" && secondary.thread ? (
        <div className="mt-8 w-full text-left">
          <ReturnThreadCard thread={secondary.thread} />
        </div>
      ) : secondary?.kind === "latest_reflection" && secondary.entry ? (
        <Link
          href={`/entry/${secondary.entry.id}`}
          className="group mt-8 block w-full rounded-2xl border border-white/10 bg-white/[0.02] p-4 text-left transition-colors hover:border-violet-400/25"
        >
          <EntryListRowMeta createdAt={secondary.entry.createdAt} />
          <p className="mt-2 line-clamp-2 text-sm leading-relaxed text-zinc-400">
            {secondary.snippet}
          </p>
          <span className="mt-3 inline-flex items-center gap-1 text-xs text-zinc-600 group-hover:text-violet-300">
            Open reflection
            <ArrowRight className="h-3.5 w-3.5" />
          </span>
        </Link>
      ) : null}

      <div className="mt-10 w-full text-left">{rhythm}</div>
    </div>
  );
}
