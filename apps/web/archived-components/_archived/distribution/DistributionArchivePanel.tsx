"use client";

import { useEffect, useMemo, useState } from "react";

import { ArchiveShareCard } from "@/archived-components/_archived/distribution/ArchiveShareCard";
import { ShareArchivePrompt } from "@/archived-components/_archived/distribution/ShareArchivePrompt";
import { TestimonialCapturePrompt } from "@/archived-components/_archived/distribution/TestimonialCapturePrompt";
import { pickPrimaryArchiveShareCard } from "@/lib/distribution/archive-share-cards";
import { syncTransformationMoments } from "@/lib/distribution/transformation-moments";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

type DistributionArchivePanelProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** Archive surface — sync moments, share card, referral, testimonial capture. */
export function DistributionArchivePanel({
  entriesOverride,
  className = "",
}: DistributionArchivePanelProps) {
  const hydrated = useClientHydrated();
  const [synced, setSynced] = useState(false);

  useEffect(() => {
    if (!hydrated) return;
    syncTransformationMoments(entriesOverride);
    setSynced(true);
  }, [hydrated, entriesOverride]);

  const shareCard = useMemo(
    () => (hydrated && synced ? pickPrimaryArchiveShareCard(entriesOverride) : null),
    [hydrated, synced, entriesOverride],
  );

  if (!hydrated || !synced) return null;

  return (
    <div className={`space-y-4 ${className}`} data-testid="distribution-archive-panel">
      {shareCard ? <ArchiveShareCard card={shareCard} /> : null}
      <ShareArchivePrompt />
      <TestimonialCapturePrompt />
    </div>
  );
}
