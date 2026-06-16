"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { ArchiveDetailsCollapsible } from "@/components/archive/ArchiveDetailsCollapsible";
import { ArchiveEmptyState } from "@/components/archive/ArchiveEmptyState";
import { ProgressiveArchiveHome } from "@/components/archive/ProgressiveArchiveHome";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { ArchiveAttachmentPrompt } from "@/components/archive/ArchiveAttachmentPrompt";
import { ArchiveMilestoneReturnMoment } from "@/components/archive/ArchiveMilestoneReturnMoment";
import { ArchiveMoatProof } from "@/components/archive/ArchiveMoatProof";
import { ArchiveUniquenessPanel } from "@/components/archive/ArchiveUniquenessPanel";
import { DistributionArchivePanel } from "@/components/distribution/DistributionArchivePanel";
import { ValueMomentPaywall } from "@/components/billing/ValueMomentPaywall";
import { PAYWALL_HEADLINE } from "@/lib/archive/archive-disclosure-copy";
import {
  isDisclosureLevelAtLeast,
  recordArchiveHomeVisit,
  resolveArchiveDisclosureLevel,
} from "@/lib/archive/archive-disclosure-level";
import { ARCHIVE_EMPTY_NO_BELIEF } from "@/lib/design/archive-empty-state-copy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveStateObject } from "@/lib/archive/archive-state-object";
import {
  EVIDENCE_ARCHIVE_NOT_VERDICT,
} from "@/lib/archive/evidence-archive-home-copy";
import { markFirstWorkingBeliefSeenIfNeeded } from "@/lib/archive/archive-loss-prompt";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { markBeliefRecallAnchor } from "@/lib/retention/belief-recall";
import {
  ARCHIVE_COPY_RESTRAINT,
  ARCHIVE_SURFACE_EYEBROWS,
} from "@/lib/design/archive-copy-restraint";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackArchiveBeliefViewed } from "@/lib/metrics/archive-belief-events";
import {
  trackArchiveProductHomeOpened,
  trackReflectionSixArchiveMovementSeen,
} from "@/lib/metrics/archive-as-product-events";
import { getPlanId } from "@/lib/subscription";
import type { JournalEntry } from "@/types/journal";

interface EvidenceArchiveHomeProps {
  entriesOverride?: JournalEntry[];
}

export function EvidenceArchiveHome({ entriesOverride }: EvidenceArchiveHomeProps) {
  const hydrated = useClientHydrated();
  const [entries, setEntries] = useState<JournalEntry[]>(entriesOverride ?? []);

  useEffect(() => {
    if (entriesOverride) setEntries(entriesOverride);
  }, [entriesOverride]);

  const belief = useMemo(
    () => (hydrated ? buildArchiveBeliefView(entries) : null),
    [hydrated, entries],
  );

  const state = useMemo(
    () => (hydrated ? buildArchiveStateObject(entries) : null),
    [hydrated, entries],
  );

  const stats = useMemo(
    () => (hydrated ? buildEvidenceArchiveStats(entries) : null),
    [hydrated, entries],
  );

  const snapshot = useMemo(
    () => (hydrated ? buildArchiveValueSnapshot(entries) : null),
    [hydrated, entries],
  );

  const disclosure = useMemo(
    () => (hydrated ? resolveArchiveDisclosureLevel() : null),
    [hydrated, entries],
  );

  useEffect(() => {
    if (!hydrated || !belief) return;
    recordArchiveHomeVisit();
    markFirstWorkingBeliefSeenIfNeeded();
    markBeliefRecallAnchor(belief.theoryId);
    trackArchiveBeliefViewed({ theoryId: belief.theoryId, surface: "archive_belief" });
    trackArchiveProductHomeOpened();
    if ((snapshot?.reflectionCount ?? 0) >= 6) {
      trackReflectionSixArchiveMovementSeen();
    }
  }, [hydrated, belief, snapshot?.reflectionCount]);

  if (!hydrated) return null;

  const showPaywallCta = getPlanId() !== "pro" && (stats?.reflectionCount ?? 0) >= 5;
  const leadWithBelief = (snapshot?.reflectionCount ?? 0) >= 5 && state;
  const showArchiveDetail =
    disclosure &&
    isDisclosureLevelAtLeast(disclosure.level, "L2_ENGAGED");

  const archiveBeliefChrome = state ? (
    <div className="space-y-4">
      <ArchiveMilestoneReturnMoment entriesOverride={entries} />
      <ProgressiveArchiveHome entriesOverride={entries} />
    </div>
  ) : null;

  return (
    <div data-testid="evidence-archive-home">
      <ArchivePageBlueprint
        surface="archive"
        identity={{
          eyebrow: ARCHIVE_SURFACE_EYEBROWS.archive,
          title: ARCHIVE_COPY_RESTRAINT.archive.headline,
          subheadline: ARCHIVE_COPY_RESTRAINT.archive.support,
          lead: leadWithBelief ? undefined : EVIDENCE_ARCHIVE_NOT_VERDICT,
        }}
        currentArchiveState={archiveBeliefChrome}
        mainContent={
          !state ? (
            <ArchiveEmptyState
              title={ARCHIVE_EMPTY_NO_BELIEF.headline}
              body={ARCHIVE_EMPTY_NO_BELIEF.body}
              testId="archive-belief-card"
              action={
                <Link
                  href="/#recorder"
                  className={`${ARCHIVE_TYPO.body} inline-flex font-medium text-violet-300 hover:text-violet-200`}
                >
                  {ARCHIVE_EMPTY_NO_BELIEF.ctaLabel}
                </Link>
              }
            />
          ) : showArchiveDetail ? (
            <ArchiveDetailsCollapsible
              className={ARCHIVE_SPACE.sm}
              entriesOverride={entries}
            />
          ) : null
        }
        supportingContent={
          state ? (
            <div className={`space-y-4 ${ARCHIVE_SPACE.sm}`}>
              <ArchiveUniquenessPanel entriesOverride={entries} />
              <ArchiveMoatProof entriesOverride={entries} />
              <ArchiveAttachmentPrompt entriesOverride={entries} />
              <DistributionArchivePanel entriesOverride={entries} />
              {(stats?.reflectionCount ?? 0) >= 5 ? (
                <ValueMomentPaywall surface="archive_continuity" />
              ) : null}
            </div>
          ) : null
        }
        actionArea={
          <ArchiveActionArea
            primary={
              showPaywallCta
                ? { label: PAYWALL_HEADLINE.replace(/\.$/, ""), href: "/pricing" }
                : { label: "Export my archive", href: "/archive" }
            }
            secondary={{ label: "See what changed", href: "/discover" }}
          />
        }
      />
    </div>
  );
}
