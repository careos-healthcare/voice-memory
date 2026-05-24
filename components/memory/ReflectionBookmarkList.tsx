"use client";

import {
  BookmarkIndicator,
} from "@/components/memory/ReflectionBookmarkMark";
import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import type {
  ReflectionBookmarkType,
  ReflectionBookmarkWithEntry,
} from "@/types/reflection-bookmark";

const SECTION_ORDER: ReflectionBookmarkType[] = [
  "mattered",
  "revisit_later",
  "changed_something",
];

export function ReflectionBookmarkList({
  bookmarks,
}: {
  bookmarks: ReflectionBookmarkWithEntry[];
}) {
  if (bookmarks.length === 0) return null;

  const grouped = SECTION_ORDER.map((type) => ({
    type,
    items: bookmarks.filter((bookmark) => bookmark.type === type),
  })).filter((section) => section.items.length > 0);

  return (
    <div className="space-y-20">
      {grouped.map((section) => (
        <section key={section.type} className="space-y-6">
          <ul className="space-y-8">
            {section.items.map((bookmark) => (
              <li key={`${bookmark.entryId}-${bookmark.type}`}>
                <RevisitEntryLink
                  entryId={bookmark.entryId}
                  source="bookmark"
                  className="group block space-y-2 px-1 py-2 transition-colors"
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-xs text-zinc-600">{bookmark.dateLabel}</p>
                    <BookmarkIndicator entryId={bookmark.entryId} />
                  </div>
                  {bookmark.snippet ? (
                    <p className="text-sm leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                      {bookmark.snippet}
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
        </section>
      ))}
    </div>
  );
}
