"use client";

import { useEffect, useState } from "react";
import { Bookmark } from "lucide-react";

import { ReflectionBookmarkList } from "@/components/memory/ReflectionBookmarkList";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { BOOKMARK_CHANGE_EVENT, listBookmarksWithEntries } from "@/lib/reflection-bookmarks";
import { getAllEntries } from "@/lib/storage";
import type { ReflectionBookmarkWithEntry } from "@/types/reflection-bookmark";

export default function BookmarksPage() {
  const [bookmarks, setBookmarks] = useState<ReflectionBookmarkWithEntry[] | null>(
    null,
  );

  useEffect(() => {
    const refresh = () => {
      setBookmarks(listBookmarksWithEntries(getAllEntries()));
    };
    refresh();
    window.addEventListener(BOOKMARK_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(BOOKMARK_CHANGE_EVENT, refresh);
  }, []);

  const loading = bookmarks === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle eyebrow="Bookmarks" title="Moments that mattered" />

        <p className="mt-4 text-sm leading-relaxed text-zinc-500">
          Reflections you marked — kept on this device only.
        </p>

        <div className="mt-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
          ) : bookmarks.length === 0 ? (
            <AnticipatoryEmptyState
              icon={<Bookmark className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <ReflectionBookmarkList bookmarks={bookmarks} />
          )}
        </div>
      </div>
    </div>
  );
}
