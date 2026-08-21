"use client";

import { useEffect, useState } from "react";
import { MessageCircle } from "lucide-react";

import { RelationshipContinuityNotes } from "@/archived-components/_archived/memory/RelationshipContinuityNotes";
import { ThreadListCompact } from "@/archived-components/_archived/memory/ThreadListCard";
import { AnticipatoryEmptyState } from "@/archived-components/_archived/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/archived-components/_archived/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { LoadingState } from "@/archived-components/_archived/system";
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

        <PrimaryMain>
        <MotionPageTitle title="Worth returning to" />

        <div className="mt-12 sm:mt-16">
          {loading ? (
            <LoadingState lines={4} label="Loading threads" className="py-12" />
          ) : threads.length === 0 ? (
            <AnticipatoryEmptyState
              icon={<MessageCircle className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <div className="space-y-10 sm:space-y-12">
              <RelationshipContinuityNotes notes={relationshipNotes} max={3} />
              <section aria-label="Conversation threads">
                <p className="mb-4 text-[10px] uppercase tracking-[0.2em] text-zinc-500">
                  Threads · {threads.length}
                </p>
                <ThreadListCompact threads={threads} />
              </section>
            </div>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
