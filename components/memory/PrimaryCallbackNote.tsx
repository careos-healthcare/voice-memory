"use client";

import { ResurfacingNotes } from "@/components/patterns/MemoryNote";

import type { MemoryNote } from "@/types/memory-note";

/** Single tuned callback line for quiet-first surfaces. */
export function PrimaryCallbackNote({ note }: { note: MemoryNote | null }) {
  if (!note) return null;
  return <ResurfacingNotes notes={[note]} max={1} />;
}
