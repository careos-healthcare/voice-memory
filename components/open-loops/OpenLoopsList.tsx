"use client";

import { useEffect, useState } from "react";

import { OpenLoopCard } from "@/components/open-loops/OpenLoopCard";
import { OPEN_LOOP_CHANGE_EVENT } from "@/lib/open-loops/open-loop-storage";
import { readOpenLoopPresentations } from "@/lib/runtime/read-model";
import type { OpenLoopPresentation } from "@/types/open-loop";

interface OpenLoopsListProps {
  compact?: boolean;
  maxItems?: number;
}

export function OpenLoopsList({ compact = false, maxItems }: OpenLoopsListProps) {
  const [loops, setLoops] = useState<OpenLoopPresentation[] | null>(null);

  useEffect(() => {
    const refresh = () => setLoops(readOpenLoopPresentations(true));
    refresh();
    window.addEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
  }, []);

  if (loops === null) {
    return compact ? null : (
      <p className="py-12 text-center text-sm text-zinc-700">One moment…</p>
    );
  }

  const visible = maxItems ? loops.slice(0, maxItems) : loops;
  if (visible.length === 0) return null;

  return (
    <ul className={compact ? "space-y-10" : "divide-y divide-white/[0.04]"}>
      {visible.map((loop) => (
        <li key={loop.openLoopId} className={compact ? undefined : "first:pt-0 py-12"}>
          <OpenLoopCard loop={loop} compact={compact} />
        </li>
      ))}
    </ul>
  );
}
