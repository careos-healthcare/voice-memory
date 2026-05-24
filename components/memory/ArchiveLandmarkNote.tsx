"use client";

import type { MemoryNote } from "@/types/memory-note";

export function ArchiveLandmarkNote({ note }: { note: MemoryNote | null }) {
  if (!note) return null;

  return (
    <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">{note.text}</p>
  );
}
