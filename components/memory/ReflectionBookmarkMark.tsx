"use client";

import { useState } from "react";
import { Bookmark } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  bookmarkTypeCopy,
  formatBookmarkTypeLabel,
} from "@/lib/reflection-bookmarks";
import { useReflectionBookmark } from "@/lib/hooks/useReflectionBookmark";
import type { ReflectionBookmarkType } from "@/types/reflection-bookmark";

const BOOKMARK_TYPES: ReflectionBookmarkType[] = [
  "mattered",
  "revisit_later",
  "changed_something",
];

export function MarkReflectionButton({
  entryId,
  onMarked,
}: {
  entryId: string;
  onMarked?: (type: ReflectionBookmarkType) => void;
}) {
  const { bookmark, mark, unmark } = useReflectionBookmark(entryId);
  const [open, setOpen] = useState(false);

  if (bookmark && !open) {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <p className="text-xs text-zinc-600">Marked</p>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-auto px-2 py-1 text-xs text-zinc-600 hover:text-zinc-400"
          onClick={() => setOpen(true)}
        >
          Change
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-auto px-2 py-1 text-xs text-zinc-600 hover:text-zinc-400"
          onClick={unmark}
        >
          Remove mark
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {!open && !bookmark ? (
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-auto gap-1.5 px-2 py-1.5 text-xs text-zinc-600 hover:text-zinc-400"
          onClick={() => setOpen(true)}
        >
          <Bookmark className="h-3.5 w-3.5" />
          Mark this
        </Button>
      ) : null}
      {open ? (
        <div className="space-y-2 px-1">
          <p className="text-xs text-zinc-600">Mark this as</p>
          <div className="flex flex-wrap gap-2">
            {BOOKMARK_TYPES.map((type) => (
              <Button
                key={type}
                type="button"
                variant="ghost"
                size="sm"
                className="h-auto px-2 py-1.5 text-xs text-zinc-500 hover:text-zinc-300"
                onClick={() => {
                  mark(type);
                  onMarked?.(type);
                  setOpen(false);
                }}
              >
                {formatBookmarkTypeLabel(type)}
              </Button>
            ))}
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="h-auto px-2 py-1.5 text-xs text-zinc-600 hover:text-zinc-400"
              onClick={() => setOpen(false)}
            >
              Cancel
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

export function BookmarkIndicator({
  entryId,
  bookmarkedIds,
}: {
  entryId: string;
  bookmarkedIds?: Set<string>;
}) {
  const { bookmark } = useReflectionBookmark(entryId);
  const isMarked = bookmarkedIds ? bookmarkedIds.has(entryId) : Boolean(bookmark);

  if (!isMarked) return null;

  return (
    <span
      className="inline-flex items-center gap-1 text-[10px] text-zinc-600"
      aria-label="Bookmarked"
    >
      <Bookmark className="h-3 w-3 fill-zinc-700/40 text-zinc-600" />
    </span>
  );
}

export function BookmarkTypeHint({ type }: { type: ReflectionBookmarkType }) {
  return (
    <p className="text-xs leading-relaxed text-zinc-600">{bookmarkTypeCopy(type)}</p>
  );
}
