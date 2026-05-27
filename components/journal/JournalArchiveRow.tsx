"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { EntryListRowMeta } from "@/components/memory/EntryListRowMeta";
import { primaryReflectionSnippet } from "@/lib/reflection/reflection-quality-gate";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

/** Quiet archive row — transcript stays secondary to return moments. */
export function JournalArchiveRow({ entry }: { entry: JournalEntry }) {
  const snippet = primaryReflectionSnippet(entry, 72);

  return (
    <Link
      href={`/entry/${entry.id}`}
      className="group flex items-center justify-between gap-3 rounded-xl border border-white/[0.06] bg-white/[0.015] px-4 py-3 transition-colors hover:border-white/12 hover:bg-white/[0.03]"
    >
      <div className="min-w-0 flex-1">
        <EntryListRowMeta createdAt={entry.createdAt} />
        {snippet ? (
          <p className="mt-1.5 line-clamp-1 text-xs leading-relaxed text-zinc-500">
            {snippet}
          </p>
        ) : (
          <p className="mt-1.5 text-xs text-zinc-600">Voice capture</p>
        )}
      </div>
      <ArrowRight className="h-3.5 w-3.5 shrink-0 text-zinc-700 transition-transform group-hover:translate-x-0.5 group-hover:text-zinc-500" />
    </Link>
  );
}
