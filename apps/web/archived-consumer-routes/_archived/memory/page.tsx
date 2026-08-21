"use client";

import { useEffect, useState } from "react";
import { ArchiveBeliefStickyBar } from "@/archived-components/_archived/archive/ArchiveBeliefStickyBar";
import { ArchiveProgressBar } from "@/archived-components/_archived/archive/ArchiveProgressBar";
import { ReflectionLogPanel } from "@/archived-components/_archived/archive/ReflectionLogPanel";
import { SessionMovementSummary } from "@/archived-components/_archived/archive/SessionMovementSummary";
import { BELIEF_DOMINANCE_ARCHIVE_CHANGE } from "@/lib/product/belief-dominance-copy";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { PrivacyNotice } from "@/archived-components/_archived/system";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { MEMORY_LOG_COPY } from "@/lib/design/archive-copy-restraint";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

/** Reflection Log — entries, search, filters only. Archive owns interpretation. */
export default function MemoryPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => setEntries(getMemoryEligibleEntries()));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain>
          <ArchivePageBlueprint
            surface="memory"
            identity={{
              eyebrow: BELIEF_DOMINANCE_ARCHIVE_CHANGE,
              title: MEMORY_LOG_COPY.headline,
              lead: MEMORY_LOG_COPY.support,
            }}
            currentArchiveState={
              <>
                <SessionMovementSummary
                  entriesOverride={entries}
                  surface="memory"
                  className={ARCHIVE_SPACE.sm}
                />
                <ArchiveBeliefStickyBar entriesOverride={entries} />
                <ArchiveProgressBar
                  entriesOverride={entries}
                  surface="memory"
                  className={ARCHIVE_SPACE.sm}
                />
              </>
            }
            mainContent={<ReflectionLogPanel entriesOverride={entries} />}
            actionArea={
              <ArchiveActionArea
                primary={{ label: "Open Archive", href: "/archive-belief" }}
                secondary={{ label: "Archive Activity", href: "/discover" }}
              />
            }
          />
          <PrivacyNotice className="mt-8" />
        </PrimaryMain>
      </div>
    </div>
  );
}
