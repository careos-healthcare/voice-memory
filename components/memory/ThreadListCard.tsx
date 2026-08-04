"use client";

import Link from "next/link";
import { ChevronRight } from "lucide-react";

import { cn } from "@/lib/utils";
import {
  formatThreadDateRange,
  threadRecencyLabel,
} from "@/lib/memory/conversation-threads";
import type { ConversationThread } from "@/types/conversation-thread";

export function ThreadListCard({
  thread,
  defaultCollapsed = true,
}: {
  thread: ConversationThread;
  defaultCollapsed?: boolean;
}) {
  const snippet = thread.evolution.whatCameBack?.trim();
  const showSnippet = snippet && snippet.length > 0;

  return (
    <li>
      <Link
        href={`/threads/${thread.slug}`}
        className={cn(
          "group block rounded-2xl border border-white/10 bg-white/[0.02] p-4",
          "transition-colors hover:border-violet-400/20 hover:bg-white/[0.04]",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/50",
        )}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <p className="text-base font-medium leading-snug text-zinc-100">{thread.title}</p>
            <p className="mt-2 text-xs text-zinc-500">
              {thread.mentionCount} moment{thread.mentionCount === 1 ? "" : "s"} ·{" "}
              {formatThreadDateRange(thread)} · {threadRecencyLabel(thread)}
            </p>
          </div>
          <ChevronRight
            className="mt-1 h-4 w-4 shrink-0 text-zinc-600 transition-colors group-hover:text-zinc-400"
            aria-hidden
          />
        </div>
        {showSnippet ? (
          <p
            className={cn(
              "mt-3 text-sm leading-relaxed text-zinc-400",
              defaultCollapsed && "line-clamp-2",
            )}
          >
            {snippet}
          </p>
        ) : null}
        <p className="mt-2 text-[10px] uppercase tracking-wider text-zinc-600">
          Then: {thread.firstAppearanceLabel} · Now: {thread.latestAppearanceLabel}
        </p>
      </Link>
    </li>
  );
}

export function ThreadListCompact({ threads }: { threads: ConversationThread[] }) {
  if (threads.length === 0) return null;

  return (
    <ul className="space-y-3">
      {threads.map((thread) => (
        <ThreadListCard key={thread.id} thread={thread} />
      ))}
    </ul>
  );
}
