"use client";

import Link from "next/link";

import { CopyMemoryMomentButton } from "@/components/memory/CopyMemoryMomentButton";
import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";

export function MilestoneNotes({
  milestones,
  entries = [],
  max = 1,
  title = "Turning points",
  subtitle,
}: {
  milestones: EmotionalMilestone[];
  entries?: JournalEntry[];
  max?: number;
  title?: string;
  subtitle?: string;
}) {
  const visible = milestones.slice(0, max);
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
        {visible.map((milestone, index) => (
          <MotionNoteItem key={milestone.id} tone="quiet" index={index}>
            <div className="space-y-3 px-1 py-2">
              {milestone.href ? (
                <Link href={milestone.href} className="group block">
                  <p className="text-sm font-normal leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                    {milestone.text}
                  </p>
                </Link>
              ) : (
                <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">
                  {milestone.text}
                </p>
              )}
              {entries.length > 0 ? (
                <CopyMemoryMomentButton
                  source="milestone"
                  milestone={milestone}
                  allEntries={entries}
                />
              ) : null}
            </div>
          </MotionNoteItem>
        ))}
      </MotionNoteList>
    </section>
  );
}
