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
  maxPerSection?: number;
}

export function MemoryNotesOverview({
  changed,
  faded,
  returned,
  maxPerSection = 1,
}: MemoryNotesOverviewProps) {
  const hasAny = changed.length > 0 || faded.length > 0 || returned.length > 0;
  if (!hasAny) return null;

  return (
    <div className="space-y-16">
      <MemoryNotesSection title="What changed" notes={changed} max={maxPerSection} />
      <MemoryNotesSection title="What faded" notes={faded} max={maxPerSection} />
      <MemoryNotesSection title="What came back" notes={returned} max={maxPerSection} />
    </div>
  );
}
