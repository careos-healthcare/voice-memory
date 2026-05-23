"use client";

import Link from "next/link";

import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import type { EmotionalMilestone } from "@/types/emotional-milestone";

export function MilestoneNotes({
  milestones,
  max = 1,
  title = "Turning points",
  subtitle,
}: {
  milestones: EmotionalMilestone[];
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
            {milestone.href ? (
              <Link href={milestone.href} className="group block px-1 py-2">
                <p className="text-sm font-normal leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
                  {milestone.text}
                </p>
              </Link>
            ) : (
              <p className="px-1 py-2 text-sm font-normal leading-[1.75] text-zinc-500/90">
                {milestone.text}
              </p>
            )}
          </MotionNoteItem>
        ))}
      </MotionNoteList>
    </section>
  );
}
