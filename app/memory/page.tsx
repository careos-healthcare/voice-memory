"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Brain } from "lucide-react";

import { FirstReturnMoment } from "@/components/continuity/FirstReturnMoment";
import { ReturnThreadsOverview } from "@/components/continuity/ReturnThreadsOverview";
import { FollowupPromptInline } from "@/components/conversation/FollowupPromptInline";
import { AnticipatoryEmptyState } from "@/components/memory/AnticipatoryEmptyState";
import { OpenLoopsSection } from "@/components/open-loops/OpenLoopsSection";
import { OpenLoopReturnPrompt } from "@/components/open-loops/OpenLoopReturnPrompt";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { LoadingState, PrivacyNotice } from "@/components/system";
import { ONBOARDING_MEMORY } from "@/lib/onboarding/onboarding-copy";
import { RECOGNITION_COPY } from "@/lib/product/recognition-copy";
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

        <PrimaryMain>
        <MotionPageTitle title={ONBOARDING_MEMORY.title} />
        <p className="mt-3 text-sm leading-relaxed text-muted">{RECOGNITION_COPY.journalLead}</p>
        <PrivacyNotice className="mt-4" />

        <div className="mt-12 space-y-12">
          {loading ? (
            <LoadingState lines={4} label={ONBOARDING_MEMORY.loading} className="py-8" />
          ) : !report?.hasData ? (
            <AnticipatoryEmptyState
              entryCount={entries.length}
              icon={<Brain className="h-6 w-6 text-violet-300" />}
            />
          ) : (
            <>
              <FirstReturnMoment entries={entries} className="mb-10" />
              <OpenLoopReturnPrompt />
              <OpenLoopsSection maxItems={3} />
              <ReturnThreadsOverview report={report} compact />

              <FollowupPromptInline
                prompt={followupPrompt}
                onRecordAgain={handleRecordAgain}
              />
            </>
          )}
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
