"use client";

import Link from "next/link";
import { motion } from "framer-motion";

import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import { revisitSourceFromNote } from "@/lib/refinement/revisit-experience";
import { MOTION, type NoteMotionTone } from "@/lib/motion/tokens";
import type { MemoryNote } from "@/types/memory-note";

interface MemoryNoteProps {
  note: MemoryNote;
  className?: string;
}

function quoteMotion(delay: number) {
  return {
    initial: { opacity: 0, y: MOTION.offset.subtle },
    animate: { opacity: 1, y: 0 },
    transition: { duration: MOTION.duration.fade, delay, ease: MOTION.ease },
  };
}

export function MemoryNoteView({ note, className }: MemoryNoteProps) {
  const isThenVsNow = Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());

  return (
    <article className={`space-y-5 ${className ?? ""}`}>
      <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{note.text}</p>
      {note.pastQuote ? (
        <motion.blockquote
          {...quoteMotion(isThenVsNow ? 0.22 : 0.12)}
          className="space-y-2 pl-1 text-sm leading-[1.7] text-zinc-500/85"
        >
          <p>
            &ldquo;{note.pastQuote.slice(0, 160)}
            {note.pastQuote.length > 160 ? "…" : ""}&rdquo;
          </p>
          {note.pastDateLabel ? (
            <span className="block text-xs text-zinc-600/90">{note.pastDateLabel}</span>
          ) : null}
          {note.pastEntryId ? (
            <RevisitEntryLink
              entryId={note.pastEntryId}
              source={revisitSourceFromNote(note)}
              noteId={note.id}
              noteText={note.text}
              linkRole="past"
              className="block text-xs text-zinc-600/80 transition-colors hover:text-zinc-400"
            >
              before
            </RevisitEntryLink>
          ) : null}
        </motion.blockquote>
      ) : null}
      {note.currentQuote ? (
        <motion.blockquote
          {...quoteMotion(isThenVsNow ? 0.22 + MOTION.stagger.thenVsNow : 0.18)}
          className="space-y-2 pl-1 text-sm leading-[1.7] text-zinc-400/90"
        >
          <p>
            &ldquo;{note.currentQuote.slice(0, 160)}
            {note.currentQuote.length > 160 ? "…" : ""}&rdquo;
          </p>
          {note.currentDateLabel ? (
            <span className="block text-xs text-zinc-600/90">{note.currentDateLabel}</span>
          ) : null}
          {note.entryId ? (
            <RevisitEntryLink
              entryId={note.entryId}
              source={revisitSourceFromNote(note)}
              noteId={note.id}
              noteText={note.text}
              linkRole="target"
              className="block text-xs text-zinc-600/80 transition-colors hover:text-zinc-400"
            >
              now
            </RevisitEntryLink>
          ) : null}
        </motion.blockquote>
      ) : null}
    </article>
  );
}

interface MemoryNotesSectionProps {
  title: string;
  notes: MemoryNote[];
  max?: number;
}

function AnimatedNotes({
  notes,
  max = 3,
  tone = "default",
  renderNote,
  listClassName = "space-y-16 py-1",
}: {
  notes: MemoryNote[];
  max?: number;
  tone?: NoteMotionTone;
  renderNote?: (note: MemoryNote) => React.ReactNode;
  listClassName?: string;
}) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <MotionNoteList className={listClassName}>
      {visible.map((note, index) => (
        <MotionNoteItem key={note.id} index={index} tone={tone}>
          {renderNote ? renderNote(note) : <MemoryNoteView note={note} />}
        </MotionNoteItem>
      ))}
    </MotionNoteList>
  );
}

export function MemoryNotesSection({ title, notes, max = 3 }: MemoryNotesSectionProps) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <section className="space-y-10">
      <h2 className="text-xs font-normal tracking-wide text-zinc-600">{title}</h2>
      <AnimatedNotes notes={visible} max={visible.length} />
    </section>
  );
}

interface MemoryNotesOverviewProps {
  changed: MemoryNote[];
  faded: MemoryNote[];
  returned: MemoryNote[];
  landmarks?: MemoryNote[];
  maxPerSection?: number;
  maxTotal?: number;
  maxLandmarks?: number;
}

function capNotesAcrossSections(
  changed: MemoryNote[],
  faded: MemoryNote[],
  returned: MemoryNote[],
  maxTotal: number,
): { changed: MemoryNote[]; faded: MemoryNote[]; returned: MemoryNote[] } {
  let remaining = maxTotal;
  const take = (notes: MemoryNote[]) => {
    const slice = notes.slice(0, remaining);
    remaining -= slice.length;
    return slice;
  };
  return {
    changed: take(changed),
    faded: take(faded),
    returned: take(returned),
  };
}

export function MemoryLandmarksSection({
  landmarks,
  max = 4,
}: {
  landmarks: MemoryNote[];
  max?: number;
}) {
  const visible = landmarks.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <section className="space-y-10 pt-4">
      <AnimatedNotes notes={visible} max={visible.length} listClassName="space-y-14 py-1" />
    </section>
  );
}

export function ChangeMomentsNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} />;
}

export function RevisitationNotes({
  notes,
  max = 2,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} />;
}

export function TimeMemoryNotes({
  notes,
  max = 2,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} />;
}

export function ResurfacingNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} tone="resurfacing" />;
}

export function FamiliarityNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} />;
}

export function RhythmNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} />;
}

export function FamiliarityResurfacingNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return <AnimatedNotes notes={notes} max={max} tone="resurfacing" />;
}

export function ArchiveGrowthNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return (
    <AnimatedNotes
      notes={notes}
      max={max}
      tone="quiet"
      renderNote={(note) => (
        <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">{note.text}</p>
      )}
    />
  );
}

export function ContinuationNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  return (
    <AnimatedNotes
      notes={notes}
      max={max}
      tone="continuation"
      renderNote={(note) => (
        <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">{note.text}</p>
      )}
    />
  );
}

export function AnimatedMemoryNote({
  note,
  tone = "default",
  index = 0,
}: {
  note: MemoryNote;
  tone?: NoteMotionTone;
  index?: number;
}) {
  return (
    <MotionNoteItem index={index} tone={tone}>
      <MemoryNoteView note={note} />
    </MotionNoteItem>
  );
}

export function MemoryNotesOverview({
  changed,
  faded,
  returned,
  landmarks = [],
  maxPerSection = 2,
  maxTotal = 4,
  maxLandmarks = 4,
}: MemoryNotesOverviewProps) {
  const capped = capNotesAcrossSections(changed, faded, returned, maxTotal);
  const hasNotes =
    capped.changed.length > 0 || capped.faded.length > 0 || capped.returned.length > 0;
  const hasLandmarks = landmarks.length > 0;
  if (!hasNotes && !hasLandmarks) return null;

  return (
    <div className="space-y-20">
      {hasNotes ? (
        <>
          <MemoryNotesSection title="What changed" notes={capped.changed} max={maxPerSection} />
          <MemoryNotesSection title="What faded" notes={capped.faded} max={maxPerSection} />
          <MemoryNotesSection title="What came back" notes={capped.returned} max={maxPerSection} />
        </>
      ) : null}
      {hasLandmarks ? (
        <MemoryLandmarksSection landmarks={landmarks} max={maxLandmarks} />
      ) : null}
    </div>
  );
}
