"use client";

import Link from "next/link";

import type { MemoryNote } from "@/types/memory-note";

interface MemoryNoteProps {
  note: MemoryNote;
  className?: string;
}

export function MemoryNoteView({ note, className }: MemoryNoteProps) {
  return (
    <article className={`space-y-4 ${className ?? ""}`}>
      <p className="text-base leading-relaxed text-zinc-300">{note.text}</p>
      {note.pastQuote ? (
        <blockquote className="border-l border-white/10 pl-4 text-sm leading-relaxed text-zinc-500">
          &ldquo;{note.pastQuote.slice(0, 160)}
          {note.pastQuote.length > 160 ? "…" : ""}&rdquo;
          {note.pastDateLabel ? (
            <span className="mt-1 block text-xs text-zinc-600">{note.pastDateLabel}</span>
          ) : null}
          {note.pastEntryId ? (
            <Link
              href={`/entry/${note.pastEntryId}`}
              className="mt-2 block text-xs text-zinc-600 hover:text-zinc-400"
            >
              before
            </Link>
          ) : null}
        </blockquote>
      ) : null}
      {note.currentQuote ? (
        <blockquote className="border-l border-white/5 pl-4 text-sm leading-relaxed text-zinc-400">
          &ldquo;{note.currentQuote.slice(0, 160)}
          {note.currentQuote.length > 160 ? "…" : ""}&rdquo;
          {note.currentDateLabel ? (
            <span className="mt-1 block text-xs text-zinc-600">{note.currentDateLabel}</span>
          ) : null}
          {note.entryId ? (
            <Link
              href={`/entry/${note.entryId}`}
              className="mt-2 block text-xs text-zinc-600 hover:text-zinc-400"
            >
              now
            </Link>
          ) : null}
        </blockquote>
      ) : null}
    </article>
  );
}

interface MemoryNotesSectionProps {
  title: string;
  notes: MemoryNote[];
  max?: number;
}

export function MemoryNotesSection({ title, notes, max = 3 }: MemoryNotesSectionProps) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <section className="space-y-8">
      <h2 className="text-sm font-medium text-zinc-500">{title}</h2>
      <ul className="space-y-12">
        {visible.map((note) => (
          <li key={note.id}>
            <MemoryNoteView note={note} />
          </li>
        ))}
      </ul>
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
    <section className="space-y-8 border-t border-white/5 pt-12">
      <ul className="space-y-10">
        {visible.map((note) => (
          <li key={note.id}>
            <MemoryNoteView note={note} />
          </li>
        ))}
      </ul>
    </section>
  );
}

export function RevisitationNotes({
  notes,
  max = 2,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <ul className="space-y-12">
      {visible.map((note) => (
        <li key={note.id}>
          <MemoryNoteView note={note} />
        </li>
      ))}
    </ul>
  );
}

export function TimeMemoryNotes({
  notes,
  max = 2,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <ul className="space-y-12">
      {visible.map((note) => (
        <li key={note.id}>
          <MemoryNoteView note={note} />
        </li>
      ))}
    </ul>
  );
}

export function ResurfacingNotes({
  notes,
  max = 1,
}: {
  notes: MemoryNote[];
  max?: number;
}) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <ul className="space-y-12">
      {visible.map((note) => (
        <li key={note.id}>
          <MemoryNoteView note={note} />
        </li>
      ))}
    </ul>
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
    <div className="space-y-16">
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
