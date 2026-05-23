"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { InsightCard } from "@/components/InsightCard";
import { VoicePlayback } from "@/components/VoicePlayback";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { deleteEntry, getEntry } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [entry, setEntry] = useState<JournalEntry | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const found = getEntry(params.id);
    setEntry(found ?? null);
    setLoading(false);
  }, [params.id]);

  const handleDelete = () => {
    if (!entry) return;
    deleteEntry(entry.id);
    router.push("/journal");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-16 sm:px-6">
        <SiteHeader />

        <div className="mt-4 flex items-center justify-between gap-4">
          <Button asChild variant="ghost" size="sm">
            <Link href="/journal">
              <ArrowLeft className="h-4 w-4" />
              Reflections
            </Link>
          </Button>
          {!loading && entry ? (
            <Button variant="ghost" size="sm" onClick={handleDelete}>
              <Trash2 className="h-4 w-4" />
              Delete
            </Button>
          ) : null}
        </div>

        {loading ? (
          <div className="mt-8 space-y-4">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-40 w-full" />
            <Skeleton className="h-32 w-full" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-16 text-center"
          >
            <p className="text-lg font-medium text-white">Entry not found</p>
            <p className="mt-2 text-sm text-zinc-400">
              This reflection may have been deleted or never saved on this device.
            </p>
            <Button asChild className="mt-6">
              <Link href="/">Record a new entry</Link>
            </Button>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-8"
          >
            <div className="mb-8">
              <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
                Reflection
              </p>
              <h1 className="mt-2 text-3xl font-semibold text-white">
                {formatEntryDate(entry.createdAt)}
              </h1>
              <p className="mt-2 text-sm text-zinc-500">
                {entry.durationSeconds}s voice reflection · saved locally
              </p>
            </div>

            <div className="mb-6">
              <VoicePlayback
                entryId={entry.id}
                audioId={entry.audioId}
                durationSeconds={entry.durationSeconds}
              />
            </div>

            <InsightCard
              reflection={entry.reflection}
              transcript={entry.transcript}
              showTranscript
            />
          </motion.div>
        )}
      </div>
    </div>
  );
}
