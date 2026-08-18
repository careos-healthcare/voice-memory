"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { EntryListRowMeta } from "@/components/memory/EntryListRowMeta";
import type { ReturnThread } from "@/types/return-thread";

function formatQuote(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) return "";
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) return trimmed;
  return `"${trimmed}"`;
}

interface ReturnThreadCardProps {
  thread: ReturnThread;
  href?: string;
}

export function ReturnThreadCard({ thread, href }: ReturnThreadCardProps) {
  const targetId = thread.relatedEntryIds[thread.relatedEntryIds.length - 1];
  const link = href ?? (targetId ? `/entry/${targetId}` : "/journal");
  const showEarlierNow =
    thread.type === "changed_position" ||
    thread.type === "contradiction" ||
    thread.type === "emotional_reversal";
  const anchor = formatQuote(thread.anchorQuote);
  const latest = formatQuote(thread.latestQuote);

  return (
    <Link
      href={link}
      className="group block rounded-2xl border border-white/10 bg-white/[0.02] p-4 transition-colors hover:border-violet-400/25 hover:bg-white/[0.04]"
    >
      <p className="text-sm leading-relaxed text-violet-100/90">{thread.continuityLine}</p>

      {showEarlierNow && anchor && latest && anchor !== latest ? (
        <div className="mt-4 space-y-3 border-t border-white/5 pt-4 text-sm leading-relaxed text-zinc-300">
          <div>
            <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
              Earlier
            </p>
            <p className="mt-1 italic text-zinc-400">{anchor}</p>
          </div>
          <div>
            <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
              Now
            </p>
            <p className="mt-1 italic text-zinc-200">{latest}</p>
          </div>
        </div>
      ) : latest ? (
        <p className="mt-3 line-clamp-3 text-sm italic leading-relaxed text-zinc-400">
          {latest}
        </p>
      ) : null}

      <div className="mt-4 flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2 text-xs text-zinc-600">
          <EntryListRowMeta createdAt={thread.lastSeenAt} />
          {thread.gapDays && thread.gapDays > 0 ? (
            <span>
              {thread.gapDays} day{thread.gapDays === 1 ? "" : "s"} between
            </span>
          ) : null}
          {thread.contextLabel && thread.type === "recurring_person" ? (
            <span className="rounded-full bg-white/[0.04] px-2 py-0.5 text-zinc-500">
              {thread.contextLabel}
            </span>
          ) : null}
        </div>
        <ArrowRight className="h-4 w-4 shrink-0 text-zinc-600 transition-transform group-hover:translate-x-0.5 group-hover:text-violet-300" />
      </div>
    </Link>
  );
}
