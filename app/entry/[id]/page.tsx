"use client";

import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { MemoryNoteView } from "@/components/patterns/MemoryNote";
import { VoicePlayback } from "@/components/VoicePlayback";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { deleteEntry, getAllEntries, getEntry } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [entry, setEntry] = useState<JournalEntry | undefined>(undefined);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const found = getEntry(params.id);
    setEntry(found ?? undefined);
    setLoading(false);
  }, [params.id]);

  const allEntries = useMemo(() => getAllEntries(), [entry]);

  const notes = useMemo(() => {
    if (!entry) return null;
    return entryMemoryNotes(allEntries, entry.id);
  }, [entry, allEntries]);

  const handleDelete = () => {
    if (!entry) return;
    deleteEntry(entry.id);
    router.push("/journal");
  };

  const whatChangedLine =
    notes?.whatChanged &&
    notes.whatChanged.id !== notes.callback?.id &&
    notes.whatChanged.id !== notes.thenVsNow?.id
      ? notes.whatChanged
      : null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
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
          <div className="mt-8 space-y-8">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : !entry ? (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-16 text-center"
          >
            <p className="text-lg font-medium text-white">Entry not found</p>
            <Button asChild className="mt-6">
              <Link href="/">Record a new entry</Link>
            </Button>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-8 space-y-16"
          >
            <header>
              <h1 className="text-2xl font-semibold text-white">
                {formatEntryDate(entry.createdAt)}
              </h1>
            </header>

            {notes?.callback ? <MemoryNoteView note={notes.callback} /> : null}

            {notes?.thenVsNow ? <MemoryNoteView note={notes.thenVsNow} /> : null}

            <VoicePlayback
              entryId={entry.id}
              audioId={entry.audioId}
              durationSeconds={entry.durationSeconds}
            />

            {entry.transcript ? (
              <div className="space-y-3">
                <p className="text-sm leading-relaxed text-zinc-400">{entry.transcript}</p>
              </div>
            ) : null}

            {whatChangedLine ? (
              <p className="text-sm leading-relaxed text-zinc-500">{whatChangedLine.text}</p>
            ) : null}
          </motion.div>
        )}
      </div>
    </div>
  );
}
