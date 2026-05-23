"use client";

import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Trash2 } from "lucide-react";

import { MemoryNoteView, ChangeMomentsNotes, FamiliarityNotes, ResurfacingNotes, RevisitationNotes, TimeMemoryNotes } from "@/components/patterns/MemoryNote";
import { VoicePlayback } from "@/components/VoicePlayback";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryFamiliarityNotes } from "@/lib/memory/familiarity";
import { entryResurfacingNotes } from "@/lib/memory/resurfacing";
import { entryRevisitationNotes } from "@/lib/memory/revisitation";
import { entryTimeMemoryNotes } from "@/lib/memory/time-memory";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { useQuietMode } from "@/lib/hooks/useQuietMode";
import { deleteEntry, getAllEntries, getEntry } from "@/lib/storage";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

function isDuplicateNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

export default function EntryPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { limits } = useQuietMode();
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

  const resurfacing = useMemo(() => {
    if (!entry) return [];
    const raw = entryResurfacingNotes(allEntries, entry.id, limits.resurfacing);
    const shown = [
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.resurfacing);
  }, [entry, allEntries, notes, limits.resurfacing]);

  const timeMemory = useMemo(() => {
    if (!entry) return [];
    const raw = entryTimeMemoryNotes(allEntries, entry.id);
    const shown = [
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, 1);
  }, [entry, allEntries, notes, resurfacing]);

  const revisitation = useMemo(() => {
    if (!entry) return [];
    const raw = entryRevisitationNotes(allEntries, entry.id);
    const shown = [
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, 1);
  }, [entry, allEntries, notes, resurfacing, timeMemory]);

  const changeMoments = useMemo(() => {
    if (!entry) return [];
    const raw = entryChangeMomentsNotes(allEntries, entry.id, limits.changeMoments);
    const shown = [
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
      ...revisitation,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.changeMoments);
  }, [entry, allEntries, notes, resurfacing, timeMemory, revisitation, limits.changeMoments]);

  const familiarity = useMemo(() => {
    if (!entry) return [];
    const raw = entryFamiliarityNotes(allEntries, entry.id, limits.familiarity);
    const shown = [
      notes?.primaryCallback,
      notes?.secondaryCallback,
      ...(notes?.thenVsNow ?? []),
      notes?.whatChanged,
      ...resurfacing,
      ...timeMemory,
      ...revisitation,
      ...changeMoments,
    ].filter(Boolean) as MemoryNote[];
    return raw.filter((r) => !shown.some((s) => isDuplicateNote(r, s))).slice(0, limits.familiarity);
  }, [
    entry,
    allEntries,
    notes,
    resurfacing,
    timeMemory,
    revisitation,
    changeMoments,
    limits.familiarity,
  ]);

  const whatChangedLine = useMemo(() => {
    if (!notes?.whatChanged) return null;
    const wc = notes.whatChanged;
    if (isDuplicateNote(wc, notes.primaryCallback)) return null;
    if (isDuplicateNote(wc, notes.secondaryCallback)) return null;
    if (notes.thenVsNow.some((t) => isDuplicateNote(wc, t))) return null;
    return wc;
  }, [notes]);

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

            {notes?.primaryCallback ? <MemoryNoteView note={notes.primaryCallback} /> : null}

            {notes?.secondaryCallback &&
            !isDuplicateNote(notes.secondaryCallback, notes.primaryCallback) ? (
              <MemoryNoteView note={notes.secondaryCallback} />
            ) : null}

            {notes?.thenVsNow.map((note) => (
              <MemoryNoteView key={note.id} note={note} />
            ))}

            <ChangeMomentsNotes notes={changeMoments} max={limits.changeMoments} />
            <FamiliarityNotes notes={familiarity} max={limits.familiarity} />
            <ResurfacingNotes notes={resurfacing} max={limits.resurfacing} />
            <RevisitationNotes notes={revisitation} max={1} />
            <TimeMemoryNotes notes={timeMemory} max={1} />

            <VoicePlayback
              entryId={entry.id}
              audioId={entry.audioId}
              durationSeconds={entry.durationSeconds}
            />

            {entry.transcript ? (
              <p className="text-sm leading-relaxed text-zinc-400">{entry.transcript}</p>
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
