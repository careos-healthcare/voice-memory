"use client";

import Link from "next/link";

import { MotionNoteItem, MotionNoteList } from "@/components/motion/MotionNote";
import type { MemoryReminder } from "@/types/memory-reminder";

export function MemoryReminderNote({
  reminder,
}: {
  reminder: MemoryReminder | null;
}) {
  if (!reminder) return null;

  return (
    <MotionNoteList className="py-1">
      <MotionNoteItem tone="quiet" index={0}>
        <Link href={reminder.href} className="group block space-y-2 px-1 py-2">
          <p className="text-sm font-normal leading-[1.75] text-zinc-500/90 transition-colors group-hover:text-zinc-400">
            {reminder.text}
          </p>
          {reminder.pastDateLabel ? (
            <p className="text-xs text-zinc-600">{reminder.pastDateLabel}</p>
          ) : null}
        </Link>
      </MotionNoteItem>
    </MotionNoteList>
  );
}

export function MemoryReminderList({
  reminders,
}: {
  reminders: MemoryReminder[];
}) {
  if (reminders.length === 0) return null;

  return (
    <ul className="space-y-6">
      {reminders.map((reminder) => (
        <li key={reminder.id}>
          <Link href={reminder.href} className="group block space-y-2 px-1 py-2">
            <p className="text-sm font-normal leading-[1.75] text-zinc-400 transition-colors group-hover:text-zinc-300">
              {reminder.text}
            </p>
            {reminder.pastDateLabel ? (
              <p className="text-xs text-zinc-600">{reminder.pastDateLabel}</p>
            ) : null}
          </Link>
        </li>
      ))}
    </ul>
  );
}
