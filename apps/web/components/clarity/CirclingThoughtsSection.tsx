"use client";

import { useEffect, useState } from "react";

import { CLARITY_CIRCLING_SECTION_TITLE } from "@/lib/clarity/clarity-copy";
import { readCirclingThoughtsForEntry } from "@/lib/runtime/read-model";
import type { CirclingThoughtsDisplay } from "@/types/clarity";

export function CirclingThoughtsSection({ entryId }: { entryId: string }) {
  const [display, setDisplay] = useState<CirclingThoughtsDisplay | null>(null);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setDisplay(readCirclingThoughtsForEntry(entryId));
    });
    return () => cancelAnimationFrame(id);
  }, [entryId]);

  if (!display || display.items.length === 0) return null;

  return (
    <details
      className="rounded-lg border border-white/[0.06] bg-zinc-900/25 px-3 py-2"
      open={open}
      onToggle={(event) => setOpen((event.target as HTMLDetailsElement).open)}
    >
      <summary className="cursor-pointer text-sm text-zinc-500 hover:text-zinc-400">
        {CLARITY_CIRCLING_SECTION_TITLE}
      </summary>
      <ul className="mt-3 space-y-2">
        {display.items.map((item) => (
          <li
            key={`${item.kind}-${item.quote}`}
            className="text-sm font-normal leading-[1.75] text-zinc-500/90"
          >
            &ldquo;{item.quote}&rdquo;
          </li>
        ))}
      </ul>
    </details>
  );
}
