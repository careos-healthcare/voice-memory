"use client";

import Link from "next/link";

import { ThreadListCompact } from "@/archived-components/_archived/memory/ThreadListCard";
import { BookmarkIndicator } from "@/archived-components/_archived/memory/ReflectionBookmarkMark";
import { RevisitEntryLink } from "@/archived-components/_archived/navigation/RevisitEntryLink";
import {
  formatThreadDateRange,
  threadRecencyLabel,
} from "@/lib/memory/conversation-threads";
import { useBookmarkedEntryIds } from "@/lib/hooks/useReflectionBookmark";
import type { ConversationThread } from "@/types/conversation-thread";

export function ThreadMentionsSection({
  threads,
  title,
}: {
  threads: ConversationThread[];
  title?: string;
}) {
  if (threads.length === 0) return null;

  return (
    <section className="space-y-6">
      {title ? (
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">{title}</h2>
      ) : null}
      <ul className="space-y-4">
        {threads.map((thread) => (
          <li key={thread.id}>
            <Link
              href={`/threads/${thread.slug}`}
              className="group block space-y-2 px-1 py-2 transition-colors"
            >
              <p className="text-sm font-normal text-zinc-400 transition-colors group-hover:text-zinc-300">
                {thread.title}
              </p>
              <p className="text-xs text-zinc-600">
                {thread.mentionCount} reflection{thread.mentionCount === 1 ? "" : "s"} ·{" "}
                {formatThreadDateRange(thread)} · {threadRecencyLabel(thread)}
              </p>
            </Link>
          </li>
        ))}
      </ul>
      <Link
        href="/threads"
        className="inline-block px-1 text-xs text-zinc-600 transition-colors hover:text-zinc-400"
      >
        All of them
      </Link>
    </section>
  );
}

export function ThreadList({
  threads,
}: {
  threads: ConversationThread[];
}) {
  return <ThreadListCompact threads={threads} />;
}

export function ThreadDetail({
  thread,
}: {
  thread: ConversationThread;
}) {
  const { evolution } = thread;
  const bookmarkedIds = useBookmarkedEntryIds();
  const evolutionBlocks = [
    evolution.whatChanged
      ? { title: "This changed", text: evolution.whatChanged }
      : null,
    evolution.whatFaded
      ? { title: "This got quieter", text: evolution.whatFaded }
      : null,
    evolution.whatCameBack
      ? { title: "You came back", text: evolution.whatCameBack }
      : null,
  ].filter(Boolean) as Array<{ title: string; text: string }>;
  const showEvolutionTitles = evolutionBlocks.length > 1;

  return (
    <div className="space-y-20">
      <header className="space-y-4">
        <h1 className="text-2xl font-normal tracking-tight text-zinc-100 sm:text-3xl">
          {thread.title}
        </h1>
        <p className="text-sm text-muted">
          {thread.mentionCount} related reflection
          {thread.mentionCount === 1 ? "" : "s"}
        </p>
        <div className="flex flex-wrap gap-x-6 gap-y-2 text-xs text-muted">
          <span>Older: {thread.firstAppearanceLabel}</span>
          <span>Today: {thread.latestAppearanceLabel}</span>
        </div>
      </header>

      {evolutionBlocks.length > 0 ? (
        <section className="space-y-8">
          {evolutionBlocks.map((block) => (
            <div key={block.title} className="space-y-2 px-1">
              {showEvolutionTitles ? (
                <h2 className="text-xs font-normal tracking-wide text-zinc-600">
                  {block.title}
                </h2>
              ) : null}
              <p className="text-sm leading-[1.75] text-zinc-500/90">{block.text}</p>
            </div>
          ))}
        </section>
      ) : null}

      <section className="space-y-6">
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">Older</h2>
        <ul className="space-y-6">
          {thread.relatedEntries.map((related) => (
            <li key={related.entryId}>
              <RevisitEntryLink
                entryId={related.entryId}
                source="thread"
                className="group block space-y-2 px-1 py-2 transition-colors"
              >
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-xs text-zinc-600">{related.dateLabel}</p>
                  <BookmarkIndicator
                    entryId={related.entryId}
                    bookmarkedIds={bookmarkedIds}
                  />
                </div>
                {related.snippet ? (
                  <p className="line-clamp-3 text-sm leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                    {related.snippet}
                  </p>
                ) : (
                  <p className="text-sm text-zinc-600 transition-colors group-hover:text-zinc-400">
                    View reflection
                  </p>
                )}
              </RevisitEntryLink>
            </li>
          ))}
        </ul>
        {thread.entryIds.length > thread.relatedEntries.length ? (
          <p className="px-1 text-xs text-zinc-600">
            +{thread.entryIds.length - thread.relatedEntries.length} earlier
            reflection
            {thread.entryIds.length - thread.relatedEntries.length === 1 ? "" : "s"}
          </p>
        ) : null}
      </section>
    </div>
  );
}
