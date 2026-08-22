"use client";

import { useCallback, useEffect, useState } from "react";

import {
  BOOKMARK_CHANGE_EVENT,
  getBookmarkForEntry,
  getBookmarkedEntryIds,
  removeBookmark,
  setBookmark,
} from "@/lib/reflection-bookmarks";
import type { ReflectionBookmark, ReflectionBookmarkType } from "@/types/reflection-bookmark";

export function useReflectionBookmark(entryId: string) {
  const [bookmark, setLocalBookmark] = useState<ReflectionBookmark | null>(null);

  const refresh = useCallback(() => {
    setLocalBookmark(getBookmarkForEntry(entryId));
  }, [entryId]);

  useEffect(() => {
    refresh();
    window.addEventListener(BOOKMARK_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(BOOKMARK_CHANGE_EVENT, refresh);
  }, [refresh]);

  const mark = useCallback(
    (type: ReflectionBookmarkType) => {
      setLocalBookmark(setBookmark(entryId, type));
    },
    [entryId],
  );

  const unmark = useCallback(() => {
    removeBookmark(entryId);
    setLocalBookmark(null);
  }, [entryId]);

  return { bookmark, mark, unmark, refresh };
}

export function useBookmarkedEntryIds() {
  const [bookmarkedIds, setBookmarkedIds] = useState<Set<string>>(new Set());

  const refresh = useCallback(() => {
    setBookmarkedIds(getBookmarkedEntryIds());
  }, []);

  useEffect(() => {
    refresh();
    window.addEventListener(BOOKMARK_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(BOOKMARK_CHANGE_EVENT, refresh);
  }, [refresh]);

  return bookmarkedIds;
}
