"use client";

import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { BookmarkIndicator } from "@/components/memory/ReflectionBookmarkMark";
import {
  formatThreadDateRange,
  formatThreadSourceLabel,
  threadRecencyLabel,
} from "@/lib/memory/conversation-threads";
import { useBookmarkedEntryIds } from "@/lib/hooks/useReflectionBookmark";
import type { ConversationThread } from "@/types/conversation-thread";

export function ThreadMentionsSection({
  threads,
  title = "Conversation threads",
  subtitle,
}: {
  threads: ConversationThread[];
  title?: string;
  subtitle?: string;
}) {
  if (threads.length === 0) return null;

  return (
    <section className="space-y-6">
      <div>
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">{title}</h2>
        {subtitle ? (
          <p className="mt-1 text-xs leading-relaxed text-zinc-600">{subtitle}</p>
        ) : null}
      </div>
      <ul className="space-y-4">
        {threads.map((thread) => (
          <li key={thread.id}>
            <Link
              href={`/threads/${thread.slug}`}
              className="group block space-y-2 px-1 py-2 transition-colors"
            >
              <div className="flex flex-wrap items-center gap-2">
                <p className="text-sm font-normal text-zinc-400 transition-colors group-hover:text-zinc-300">
                  {thread.title}
                </p>
                <Badge variant="secondary" className="text-[10px] font-normal">
                  {formatThreadSourceLabel(thread.source)}
                </Badge>
              </div>
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
        All conversation threads
      </Link>
    </section>
  );
}

export function ThreadList({
  threads,
}: {
  threads: ConversationThread[];
}) {
  if (threads.length === 0) return null;

  return (
    <ul className="space-y-10">
      {threads.map((thread) => (
        <li key={thread.id}>
          <Link
            href={`/threads/${thread.slug}`}
            className="group block space-y-3 px-1 py-1 transition-colors"
          >
            <div className="flex flex-wrap items-center gap-2">
              <p className="text-base font-normal text-zinc-200 transition-colors group-hover:text-zinc-100">
                {thread.title}
              </p>
              <Badge variant="secondary" className="text-[10px] font-normal">
                {formatThreadSourceLabel(thread.source)}
              </Badge>
            </div>
            <p className="text-xs text-zinc-500">
              {thread.mentionCount} reflection{thread.mentionCount === 1 ? "" : "s"}
            </p>
            <p className="text-xs text-zinc-600">
              First: {thread.firstAppearanceLabel} · Latest:{" "}
              {thread.latestAppearanceLabel}
            </p>
            {thread.evolution.whatCameBack ? (
              <p className="text-sm leading-relaxed text-zinc-500/90">
                {thread.evolution.whatCameBack}
              </p>
            ) : null}
          </Link>
        </li>
      ))}
    </ul>
  );
}

export function ThreadDetail({
  thread,
}: {
  thread: ConversationThread;
}) {
  const { evolution } = thread;
  const bookmarkedIds = useBookmarkedEntryIds();

  return (
    <div className="space-y-20">
      <header className="space-y-4">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="text-2xl font-normal tracking-tight text-zinc-100 sm:text-3xl">
            {thread.title}
          </h1>
          <Badge variant="secondary" className="text-[10px] font-normal">
            {formatThreadSourceLabel(thread.source)}
          </Badge>
        </div>
        <p className="text-sm text-zinc-500">
          {thread.mentionCount} related reflection
          {thread.mentionCount === 1 ? "" : "s"}
        </p>
        <div className="flex flex-wrap gap-x-6 gap-y-2 text-xs text-zinc-600">
          <span>First appearance: {thread.firstAppearanceLabel}</span>
          <span>Latest appearance: {thread.latestAppearanceLabel}</span>
        </div>
      </header>

      {(evolution.whatChanged || evolution.whatFaded || evolution.whatCameBack) && (
        <section className="space-y-8">
          {evolution.whatChanged ? (
            <div className="space-y-2 px-1">
              <h2 className="text-xs font-normal tracking-wide text-zinc-600">
                What changed
              </h2>
              <p className="text-sm leading-[1.75] text-zinc-500/90">
                {evolution.whatChanged}
              </p>
            </div>
          ) : null}
          {evolution.whatFaded ? (
            <div className="space-y-2 px-1">
              <h2 className="text-xs font-normal tracking-wide text-zinc-600">
                What faded
              </h2>
              <p className="text-sm leading-[1.75] text-zinc-500/90">
                {evolution.whatFaded}
              </p>
            </div>
          ) : null}
          {evolution.whatCameBack ? (
            <div className="space-y-2 px-1">
              <h2 className="text-xs font-normal tracking-wide text-zinc-600">
                What came back
              </h2>
              <p className="text-sm leading-[1.75] text-zinc-500/90">
                {evolution.whatCameBack}
              </p>
            </div>
          ) : null}
        </section>
      )}

      <section className="space-y-6">
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">
          Related entries
        </h2>
        <ul className="space-y-6">
          {thread.relatedEntries.map((related) => (
            <li key={related.entryId}>
              <Link
                href={`/entry/${related.entryId}`}
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
                  <p className="text-sm leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                    {related.snippet}
                  </p>
                ) : (
                  <p className="text-sm text-zinc-600 transition-colors group-hover:text-zinc-400">
                    View reflection
                  </p>
                )}
              </Link>
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
