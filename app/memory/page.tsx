"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Brain } from "lucide-react";

import { ReturnThreadsOverview } from "@/components/continuity/ReturnThreadsOverview";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { OpenLoopsSection } from "@/components/open-loops/OpenLoopsSection";
import { OpenLoopReturnPrompt } from "@/components/open-loops/OpenLoopReturnPrompt";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { SiteHeader } from "@/components/SiteHeader";
import { ONBOARDING_MEMORY } from "@/lib/onboarding/onboarding-copy";
import { PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { Button } from "@/components/ui/button";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { followupPromptFromReturnThreads } from "@/lib/continuity/followup-from-threads";
import {
  buildRecordReturnFromFollowup,
  storeRecordReturnContext,
} from "@/lib/reflection/record-return";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { ReturnThreadsReport } from "@/types/return-thread";

export default function MemoryPage() {
  const router = useRouter();
  const [report, setReport] = useState<ReturnThreadsReport | null>(null);
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => {
      const list = getMemoryEligibleEntries();
      setEntries(list);
      setReport(buildReturnThreads(list));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;

  const followupPrompt = useMemo(
    () => followupPromptFromReturnThreads(report, entries),
    [report, entries],
  );

  const handleRecordAgain = (prompt: FollowupPrompt) => {
    storeRecordReturnContext(buildRecordReturnFromFollowup(prompt));
    router.push("/#recorder");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <MotionPageTitle title={ONBOARDING_MEMORY.title} />
        <p className="mt-3 text-sm leading-relaxed text-zinc-500">{PRODUCT_WEDGE_LINE}</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-600">{ONBOARDING_MEMORY.wedge}</p>

        <div className="mt-12 space-y-12">
          {loading ? (
            <p className="py-20 text-center text-sm text-zinc-600">{ONBOARDING_MEMORY.loading}</p>
          ) : !report?.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <div className="px-2 py-16 text-center">
                <Brain className="mx-auto h-7 w-7 text-zinc-600/80" />
                <p className="mt-5 text-base font-normal text-zinc-400">{ONBOARDING_MEMORY.empty}</p>
                <Button asChild className="mt-8" variant="secondary">
                  <Link href="/">Start recording</Link>
                </Button>
              </div>
            </>
          ) : (
            <>
              <OpenLoopReturnPrompt />
              <OpenLoopsSection maxItems={3} />
              <ReturnThreadsOverview report={report} />

              <FollowupPromptInline
                prompt={followupPrompt}
                onRecordAgain={handleRecordAgain}
              />
            </>
          )}
        </div>
      </div>
    </div>
  );
}
