"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { ThreadDetail } from "@/components/memory/ConversationThreadSection";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { getConversationThreadBySlug } from "@/lib/memory/conversation-threads";
import { getAllEntries } from "@/lib/storage";
import type { ConversationThread } from "@/types/conversation-thread";

export default function ThreadDetailPage() {
  const params = useParams<{ slug: string }>();
  const [thread, setThread] = useState<ConversationThread | null | undefined>(
    undefined,
  );

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const found = getConversationThreadBySlug(getAllEntries(), params.slug);
      setThread(found ?? null);
    });
    return () => cancelAnimationFrame(id);
  }, [params.slug]);

  const loading = thread === undefined;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <div className="mt-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/threads">
              <ArrowLeft className="h-4 w-4" />
              All threads
            </Link>
          </Button>
        </div>

        <div className="mt-10">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">Reading your archive…</p>
          ) : !thread ? (
            <div className="py-16 text-center">
              <p className="text-lg font-normal text-zinc-200">Thread not found</p>
              <Button asChild className="mt-6" variant="secondary">
                <Link href="/threads">Back to threads</Link>
              </Button>
            </div>
          ) : (
            <ThreadDetail thread={thread} />
          )}
        </div>
      </div>
    </div>
  );
}
