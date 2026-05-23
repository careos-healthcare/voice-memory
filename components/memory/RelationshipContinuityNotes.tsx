"use client";

import Link from "next/link";

import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import type { RelationshipContinuityNote } from "@/types/relationship-continuity";

export function RelationshipContinuityNotes({
  notes,
  max = 4,
  title = "People over time",
  subtitle,
}: {
  notes: RelationshipContinuityNote[];
  max?: number;
  title?: string;
  subtitle?: string;
}) {
  const visible = notes.slice(0, max);
  if (visible.length === 0) return null;

  return (
    <section className="space-y-6">
      <div>
        <h2 className="text-xs font-normal tracking-wide text-zinc-600">{title}</h2>
        {subtitle ? (
          <p className="mt-1 text-xs leading-relaxed text-zinc-600">{subtitle}</p>
        ) : null}
      </div>
      <MotionNoteList className="space-y-4">
        {visible.map((note, index) => (
          <MotionNoteItem key={note.id} tone="quiet" index={index}>
            {note.href ? (
              <Link href={note.href} className="group block px-1 py-2">
                <p className="text-sm font-normal leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                  {note.text}
                </p>
              </Link>
            ) : (
              <p className="px-1 py-2 text-sm font-normal leading-[1.75] text-zinc-500/90">
                {note.text}
              </p>
            )}
          </MotionNoteItem>
        ))}
      </MotionNoteList>
    </section>
  );
}
