"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MessageCircle } from "lucide-react";

import { RelationshipContinuityNotes } from "@/components/memory/RelationshipContinuityNotes";
import { ThreadList } from "@/components/memory/ConversationThreadSection";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { threadsRelationshipNotes } from "@/lib/memory/relationship-continuity";
import { listConversationThreads } from "@/lib/memory/conversation-threads";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { RelationshipContinuityNote } from "@/types/relationship-continuity";
import type { ConversationThread } from "@/types/conversation-thread";

export default function ThreadsPage() {
  const [threads, setThreads] = useState<ConversationThread[] | null>(null);
  const [relationshipNotes, setRelationshipNotes] = useState<RelationshipContinuityNote[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      setThreads(listConversationThreads(entries));
      setRelationshipNotes(threadsRelationshipNotes(entries, 3));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = threads === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle title="Worth returning to" />

        <div className="mt-20">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
          ) : threads.length === 0 ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <MessageCircle className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">
                  No ongoing conversations yet
                </p>
                <p className="mt-2 text-sm text-zinc-600">
                  These show up when you talk about the same thing more than once.
                </p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
            </>
          ) : (
            <div className="space-y-20">
              <RelationshipContinuityNotes notes={relationshipNotes} max={3} />
              <ThreadList threads={threads} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
