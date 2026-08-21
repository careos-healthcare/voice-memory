"use client";

import { useEffect, useState } from "react";

import { DiscoverWhatChanged } from "@/archived-components/_archived/archive/DiscoverWhatChanged";
import { SessionMovementSummary } from "@/archived-components/_archived/archive/SessionMovementSummary";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { DISCOVER_V3_TITLE } from "@/lib/archive/archive-reduction-v3-copy";
import { useEvolvingUnderstandingReturnCheck } from "@/lib/metrics/evolving-understanding-return";
import { DISCOVER_BACK_TO_ARCHIVE } from "@/lib/product/archive-product-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

/** What Changed — belief shifts, new evidence, watch items only. */
export default function DiscoverPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  useEvolvingUnderstandingReturnCheck("discover");

  useEffect(() => {
    const id = requestAnimationFrame(() => setEntries(getMemoryEligibleEntries()));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
          <ArchivePageBlueprint
            surface="discover"
            identity={{
              eyebrow: "Archive activity",
              title: DISCOVER_V3_TITLE,
              subheadline: "Belief changes, new evidence, and what the archive is watching.",
            }}
            whatChanged={
              <>
                <SessionMovementSummary
                  entriesOverride={entries}
                  surface="discover"
                  className="mb-6"
                />
                <DiscoverWhatChanged entriesOverride={entries} />
              </>
            }
            mainContent={null}
            actionArea={
              <ArchiveActionArea
                secondary={{
                  label: DISCOVER_BACK_TO_ARCHIVE,
                  href: "/archive-belief",
                  testId: "discover-back-archive",
                }}
              />
            }
          />
        </PrimaryMain>
      </div>
    </div>
  );
}
