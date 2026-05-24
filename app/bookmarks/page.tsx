"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Bookmark } from "lucide-react";

import { ReflectionBookmarkList } from "@/components/memory/ReflectionBookmarkList";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
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
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <Bookmark className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">
                  No bookmarks yet
                </p>
                <p className="mt-2 text-sm text-zinc-600">
                  Open a reflection and use &ldquo;Mark this&rdquo; when a moment
                  feels worth keeping.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/journal">Browse reflections</Link>
                </Button>
              </div>
            </>
          ) : (
            <ReflectionBookmarkList bookmarks={bookmarks} />
          )}
        </div>
      </div>
    </div>
  );
}
