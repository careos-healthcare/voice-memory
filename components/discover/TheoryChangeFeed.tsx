"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";

import { ValueMomentContinuityGate } from "@/components/billing/ValueMomentContinuityGate";
import { ValueMomentPaywall } from "@/components/billing/ValueMomentPaywall";
import { EvidenceFeedSection } from "@/components/discover/EvidenceFeedSection";
import { TheoryMovementFeed } from "@/components/discover/TheoryMovementFeed";
import { EvolvingViewCard } from "@/components/theories/EvolvingViewCard";
import { ArchiveLoadingState } from "@/components/archive/ArchiveLoadingState";
import { ArchiveTransition } from "@/components/archive/ArchiveTransition";
import { TheoryChangeItemCard } from "@/components/discover/TheoryChangeItemCard";
import { TheoryResolutionSection } from "@/components/discover/TheoryResolutionSection";
import { Card, CardContent } from "@/components/ui/card";
import {
  markFirstDiscoverSeen,
  recordDiscoverPageVisit,
} from "@/lib/billing/value-moment-paywall";
import { saveDiscoverVisitBaseline } from "@/lib/discover/discover-visit";
import { buildEvidenceFeed } from "@/lib/discover/evidence-feed";
import { ProductDemoStory } from "@/components/product/ProductDemoStory";
import { DISCOVER_PAGE } from "@/lib/discover/discover-copy";
import { notifyTheoryNotificationsChanged } from "@/components/theories/TheoryUpdatesNav";
import { trackActivationDiscoverySurface } from "@/lib/product/activation-metrics";
import { generateTheoryNotifications } from "@/lib/theories/theory-notification-generator";
import { countUnreadTheoryNotifications } from "@/lib/theories/theory-notification-storage";
import { buildTheoryChangeFeed } from "@/lib/discover/theory-change-feed";
import { buildTheoryMovementFeed } from "@/lib/discover/theory-movement-feed";
import { buildTheoryResolutionFeed } from "@/lib/discover/theory-resolution-feed";
import { recordDiscoverVolatilitySample } from "@/lib/discover/theory-volatility";
import { trackDiscoverProductOpened } from "@/lib/metrics/archive-as-product-events";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { markReturnExpectationPromptEligible } from "@/lib/retention/return-trigger-attribution";
import { trackTheoryEvent, THEORY_EVENTS } from "@/lib/theories/theory-events";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EvidenceFeedReport } from "@/types/evidence-feed";
import type { TheoryMovementFeedReport } from "@/types/theory-curiosity-engine";
import type { TheoryChangeFeedReport, TheoryResolutionFeedReport } from "@/types/theory";

function ChangeSection({
  title,
  items,
}: {
  title: string;
  items: import("@/types/theory").TheoryChangeItem[];
}) {
  if (items.length === 0) return null;
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-medium text-zinc-300">{title}</h2>
      <div className="space-y-3">
        {items.map((item) => (
          <TheoryChangeItemCard key={`${item.category}-${item.theoryId}`} item={item} />
        ))}
      </div>
    </section>
  );
}

export function TheoryChangeFeed() {
  const entries = useMemo(() => getMemoryEligibleEntries(), []);
  const [feed, setFeed] = useState<TheoryChangeFeedReport | null>(null);
  const [resolutionFeed, setResolutionFeed] = useState<TheoryResolutionFeedReport | null>(
    null,
  );
  const [evidenceFeed, setEvidenceFeed] = useState<EvidenceFeedReport | null>(null);
  const [movementFeed, setMovementFeed] = useState<TheoryMovementFeedReport | null>(null);
  const openedRef = useRef(false);
  const volatilityRecordedRef = useRef(false);
  const notificationsGeneratedRef = useRef(false);
  const [unreadUpdates, setUnreadUpdates] = useState(0);

  useEffect(() => {
    recordDiscoverPageVisit();
  }, []);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const change = buildTheoryChangeFeed(entries);
      const resolution = buildTheoryResolutionFeed(entries);
      setFeed(change);
      setResolutionFeed(resolution);
      setEvidenceFeed(buildEvidenceFeed(entries));
      setMovementFeed(buildTheoryMovementFeed(change, resolution));
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  useEffect(() => {
    if (!feed || !evidenceFeed || !resolutionFeed || openedRef.current) return;
    openedRef.current = true;
    trackDiscoverProductOpened();
    trackTheoryEvent(THEORY_EVENTS.discoverOpened, {
      totalChanges: String(feed.totalChanges),
      evidenceMovements: String(evidenceFeed.totalMovements),
      hasBaseline: feed.hasBaseline ? "1" : "0",
    });
    markReturnExpectationPromptEligible();
    trackActivationDiscoverySurface("discover");
    markFirstDiscoverSeen();

    if (feed.hasBaseline && !notificationsGeneratedRef.current) {
      notificationsGeneratedRef.current = true;
      generateTheoryNotifications(entries);
      setUnreadUpdates(countUnreadTheoryNotifications());
      notifyTheoryNotificationsChanged();
    }

    if (!volatilityRecordedRef.current) {
      volatilityRecordedRef.current = true;
      const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
      recordDiscoverVolatilitySample({
        totalTheories: report.all.length,
        strengthenedCount: feed.strengthened.length,
        weakenedCount: feed.weakened.length,
        resolvedCount: resolutionFeed.resolved.length + feed.resolved.length,
        retiredCount: resolutionFeed.retired.length,
        theoryChangeCount: feed.totalChanges,
        evidenceMovementCount: evidenceFeed.totalMovements,
        hasBaseline: feed.hasBaseline,
      });
    }
  }, [feed, evidenceFeed, resolutionFeed, entries]);

  useEffect(() => {
    return () => {
      const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
      saveDiscoverVisitBaseline(report.all, entries);
    };
  }, [entries]);

  if (feed === null || evidenceFeed === null || resolutionFeed === null || movementFeed === null) {
    return <ArchiveLoadingState variant="discoverFeed" ariaLabel="Discover preparing" />;
  }

  if (!feed.hasBaseline) {
    return (
      <div className="space-y-10">
        <EvolvingViewCard entriesOverride={entries} surface="discover_baseline" minReflections={1} />
        <ProductDemoStory />
        <Card className="border-dashed border-white/5">
          <CardContent className="py-14 text-center">
            <p className="text-sm font-medium text-zinc-400">
              {DISCOVER_PAGE.baselineFallbackTitle}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-600">
              {DISCOVER_PAGE.baselineFallbackBody}
            </p>
            <p className="mt-3 text-xs leading-relaxed text-zinc-600">
              {DISCOVER_PAGE.firstVisitBody}
            </p>
          </CardContent>
        </Card>
        <TheoryResolutionSection feed={resolutionFeed} />
      </div>
    );
  }

  const hasEvidence = evidenceFeed.totalMovements > 0;
  const hasTheoryChanges = feed.totalChanges > 0;

  return (
    <ArchiveTransition mode="fade" className="space-y-10">
      <TheoryMovementFeed report={movementFeed} />
      {unreadUpdates > 0 ? (
        <p className="text-center text-sm text-violet-300/90">
          <Link href="/updates" className="underline-offset-2 hover:underline">
            {unreadUpdates} archive change{unreadUpdates === 1 ? "" : "s"} since your last visit
          </Link>
        </p>
      ) : null}
      <EvidenceFeedSection
        movements={evidenceFeed.movements}
        hasBaseline={evidenceFeed.hasBaseline}
      />

      {hasTheoryChanges ? (
        <ValueMomentContinuityGate entriesOverride={entries} className="border-t border-white/5 pt-10">
          <div className="space-y-8">
            <h2 className="text-sm font-medium text-zinc-300">{DISCOVER_PAGE.theoryChangesTitle}</h2>
            <ChangeSection title={DISCOVER_PAGE.strengthenedTitle} items={feed.strengthened} />
            <ChangeSection title={DISCOVER_PAGE.weakenedTitle} items={feed.weakened} />
            <ChangeSection title={DISCOVER_PAGE.newTitle} items={feed.new} />
            <ChangeSection title={DISCOVER_PAGE.resolvedTitle} items={feed.resolved} />
          </div>
        </ValueMomentContinuityGate>
      ) : !hasEvidence ? (
        <Card className="border-dashed border-white/5">
          <CardContent className="py-10 text-center">
            <p className="text-sm font-medium text-zinc-400">{DISCOVER_PAGE.emptyTitle}</p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-600">{DISCOVER_PAGE.emptyBody}</p>
          </CardContent>
        </Card>
      ) : null}

      <ValueMomentContinuityGate entriesOverride={entries}>
        <TheoryResolutionSection feed={resolutionFeed} />
      </ValueMomentContinuityGate>

      <ValueMomentPaywall surface="discover" entriesOverride={entries} className="mt-6" />

      <p className="text-center">
        <Link href="/theories" className="text-sm text-violet-400 hover:text-violet-300">
          {DISCOVER_PAGE.viewTheoriesLink}
        </Link>
      </p>
    </ArchiveTransition>
  );
}
