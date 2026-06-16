"use client";

import { useEffect, useState } from "react";

import { ContinuityStrip } from "@/components/archive/ContinuityStrip";
import { HardToReproduceProof } from "@/components/archive/HardToReproduceProof";
import { SessionMovementSummary } from "@/components/archive/SessionMovementSummary";
import { WhatThisArchiveCanAnswer } from "@/components/archive/WhatThisArchiveCanAnswer";
import { WhyMoreEvidenceMatters } from "@/components/archive/WhyMoreEvidenceMatters";
import { BlindSpotAccelerationView } from "@/components/blind-spots/BlindSpotAccelerationView";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { ArchiveValueBanner } from "@/components/product/ArchiveValueBanner";
import { EvidenceBuildingCard } from "@/components/theories/EvidenceBuildingCard";
import { SiteHeader } from "@/components/SiteHeader";
import { PrivacyNotice } from "@/components/system";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import { BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF } from "@/lib/product/belief-dominance-copy";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export default function BlindSpotsPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => setEntries(getMemoryEligibleEntries()));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
          <p className="sr-only">{BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF}</p>
          <ArchivePageBlueprint
            surface="blind_spots"
            identity={{
              eyebrow: BLIND_SPOT_PAGE.eyebrow,
              title: BLIND_SPOT_PAGE.title,
              lead: BLIND_SPOT_PAGE.lead,
            }}
            currentArchiveState={
              <ContinuityStrip surface="blind_spots" entriesOverride={entries} />
            }
            whatChanged={
              <SessionMovementSummary
                surface="blind_spots"
                entriesOverride={entries}
                className={ARCHIVE_SPACE.md}
              />
            }
            mainContent={
              <>
                <BlindSpotAccelerationView />
                <p className={cn(ARCHIVE_TYPO.caption, ARCHIVE_SPACE.md)}>
                  {BLIND_SPOT_PAGE.disclaimer}
                </p>
              </>
            }
            supportingContent={
              <>
                <WhatThisArchiveCanAnswer className={ARCHIVE_SPACE.lg} />
                <HardToReproduceProof
                  surface="blind_spots"
                  entriesOverride={entries}
                  className={ARCHIVE_SPACE.md}
                />
                <PrivacyNotice className={ARCHIVE_SPACE.md} />
                <EvidenceBuildingCard className={ARCHIVE_SPACE.md} entriesOverride={entries} />
                <WhyMoreEvidenceMatters className={ARCHIVE_SPACE.md} entriesOverride={entries} />
                <ArchiveValueBanner className={ARCHIVE_SPACE.md} entriesOverride={entries} />
              </>
            }
            actionArea={
              <ArchiveActionArea
                primary={{
                  label: "Back to Archive",
                  href: "/archive-belief",
                  testId: "blind-spots-back-archive",
                }}
              />
            }
          />
        </PrimaryMain>
      </div>
    </div>
  );
}
