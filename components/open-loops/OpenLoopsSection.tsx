"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { OpenLoopsList } from "@/components/open-loops/OpenLoopsList";
import {
  OPEN_LOOP_EMPTY,
  OPEN_LOOP_SECTION_LEAD,
  OPEN_LOOP_SECTION_TITLE,
} from "@/lib/open-loops/open-loop-copy";
import { OPEN_LOOP_CHANGE_EVENT, getActiveOpenLoops } from "@/lib/open-loops/open-loop-storage";

interface OpenLoopsSectionProps {
  maxItems?: number;
  showEmpty?: boolean;
}

export function OpenLoopsSection({ maxItems = 3, showEmpty = false }: OpenLoopsSectionProps) {
  const [activeCount, setActiveCount] = useState(0);

  useEffect(() => {
    const refresh = () => setActiveCount(getActiveOpenLoops().length);
    refresh();
    window.addEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
  }, []);

  const hasLoops = activeCount > 0;

  if (!hasLoops && !showEmpty) return null;

  return (
    <section className="space-y-4">
      <div className="space-y-2">
        <h2 className="text-sm font-normal text-zinc-400">{OPEN_LOOP_SECTION_TITLE}</h2>
        <p className="text-xs leading-relaxed text-zinc-600">{OPEN_LOOP_SECTION_LEAD}</p>
      </div>

      {hasLoops ? (
        <>
          <OpenLoopsList compact maxItems={maxItems} />
          {activeCount > maxItems ? (
            <Link href="/open-loops" className="text-sm text-zinc-500 hover:text-zinc-300">
              View all open loops
            </Link>
          ) : null}
        </>
      ) : (
        <p className="text-sm leading-relaxed text-zinc-600">{OPEN_LOOP_EMPTY}</p>
      )}
    </section>
  );
}
