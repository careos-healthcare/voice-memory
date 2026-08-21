"use client";

import { MotionNoteItem, MotionNoteList } from "@/archived-components/_archived/motion/MotionNote";
import type { MemoryNote } from "@/types/memory-note";

/** One rare living-memory line — meaning shifts as the archive grows. */
export function LivingResurfacingNote({ note }: { note: MemoryNote | null }) {
  if (!note) return null;

  return (
    <MotionNoteList className="py-1">
      <MotionNoteItem tone="quiet" index={0}>
        <p className="px-1 py-2 text-sm font-normal leading-[1.75] text-zinc-500/90">
          {note.text}
        </p>
      </MotionNoteItem>
    </MotionNoteList>
  );
}
