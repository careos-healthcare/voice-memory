"use client";

import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import type { ContinuityDepthIndicator } from "@/types/continuity-depth";

export function ContinuityDepthNote({
  indicator,
}: {
  indicator: ContinuityDepthIndicator | null;
}) {
  if (!indicator) return null;

  return (
    <MotionNoteList className="py-1">
      <MotionNoteItem tone="quiet" index={0}>
        <p className="px-1 py-2 text-sm font-normal leading-[1.75] text-zinc-500/90">
          {indicator.text}
        </p>
      </MotionNoteItem>
    </MotionNoteList>
  );
}
