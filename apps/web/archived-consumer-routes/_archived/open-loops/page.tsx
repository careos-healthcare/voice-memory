"use client";

import { CircleDashed } from "lucide-react";

import { EntitlementGate } from "@/archived-components/_archived/billing/EntitlementGate";
import { OpenLoopsList } from "@/archived-components/_archived/open-loops/OpenLoopsList";
import { AnticipatoryEmptyState } from "@/archived-components/_archived/memory/AnticipatoryEmptyState";
import { MotionPageTitle } from "@/archived-components/_archived/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import {
  OPEN_LOOP_PAGE_TITLE,
  OPEN_LOOP_SECTION_LEAD,
  OPEN_LOOP_SECTION_TITLE,
} from "@/lib/open-loops/open-loop-copy";
import { OPEN_LOOP_CHANGE_EVENT } from "@/lib/open-loops/open-loop-storage";
import { readActiveOpenLoops } from "@/lib/runtime/read-model";
import { useEffect, useState } from "react";

export default function OpenLoopsPage() {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    const refresh = () => setCount(readActiveOpenLoops().length);
    refresh();
    window.addEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(OPEN_LOOP_CHANGE_EVENT, refresh);
  }, []);

  const loading = count === null;
  const empty = !loading && count === 0;

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-4">
        <MotionPageTitle eyebrow={OPEN_LOOP_SECTION_TITLE} title={OPEN_LOOP_PAGE_TITLE} />
        <p className="mt-6 max-w-xl text-sm leading-relaxed text-muted">
          {OPEN_LOOP_SECTION_LEAD}
        </p>

        <div className="mt-24">
          {loading ? (
            <p className="py-20 text-center text-sm text-muted" role="status">One moment…</p>
          ) : empty ? (
            <AnticipatoryEmptyState
              icon={<CircleDashed className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <EntitlementGate
              entitlement="open_loops"
              source="open_loops"
              allowExisting
              hasExisting={count > 0}
            >
              <OpenLoopsList />
            </EntitlementGate>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
