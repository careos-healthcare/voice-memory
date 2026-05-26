"use client";

import Link from "next/link";
import { CircleDashed } from "lucide-react";

import { EntitlementGate } from "@/components/billing/EntitlementGate";
import { OpenLoopsList } from "@/components/open-loops/OpenLoopsList";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import {
  OPEN_LOOP_EMPTY,
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

        <MotionPageTitle eyebrow={OPEN_LOOP_SECTION_TITLE} title={OPEN_LOOP_PAGE_TITLE} />
        <p className="mt-6 max-w-xl text-sm leading-relaxed text-zinc-600">
          {OPEN_LOOP_SECTION_LEAD}
        </p>

        <div className="mt-24">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">One moment…</p>
          ) : empty ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <CircleDashed className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">No open loops yet</p>
                <p className="mt-2 text-sm text-zinc-600">{OPEN_LOOP_EMPTY}</p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/journal">Browse reflections</Link>
                </Button>
              </div>
            </>
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
      </div>
    </div>
  );
}
