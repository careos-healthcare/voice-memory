"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { BlindSpotExperimentFollowUpStack } from "@/components/blind-spots/BlindSpotExperimentFollowUpStack";
import { InsightOutcomePromptStack } from "@/components/insights/InsightOutcomePromptStack";
import { BlindSpotReview } from "@/components/blind-spots/BlindSpotReview";
import { EvolvingViewCard } from "@/components/theories/EvolvingViewCard";
import { EmergingPatternsSection } from "@/components/blind-spots/EmergingPatternsSection";
import { PredictionReviewSection } from "@/components/blind-spots/PredictionReviewSection";
import { Card, CardContent } from "@/components/ui/card";
import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import { persistBlindSpotReviewSnapshot } from "@/lib/blind-spots/blind-spot-review-snapshots";
import { computeArchiveAgeDays } from "@/lib/blind-spots/blind-spot-events";
import { recordBlindSpotsPageVisit } from "@/lib/billing/value-moment-paywall";
import { trackActivationDiscoverySurface } from "@/lib/product/activation-metrics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BlindSpotAccelerationReport } from "@/types/blind-spot-acceleration";

export function BlindSpotAccelerationView() {
  const [acceleration, setAcceleration] = useState<BlindSpotAccelerationReport | null>(null);
  const trackedOpenRef = useRef(false);
  const entries = useMemo(() => getMemoryEligibleEntries(), []);

  const reflectionCount = entries.filter((e) => e.reflectionPending !== true).length;
  const archiveAgeDays = computeArchiveAgeDays(entries);

  useEffect(() => {
    recordBlindSpotsPageVisit();
  }, []);

  useEffect(() => {
    if (!trackedOpenRef.current) {
      trackedOpenRef.current = true;
      trackActivationDiscoverySurface("blind_spots");
    }
    const id = requestAnimationFrame(() => {
      const next = buildBlindSpotAccelerationReport(entries);
      setAcceleration(next);
      if (next.mainReview.kind === "ready") {
        persistBlindSpotReviewSnapshot(next.mainReview.review);
      }
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  if (acceleration === null) {
    return (
      <Card>
        <CardContent className="py-16 text-center text-sm text-muted" role="status">
          Reading your thinking history…
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-12">
      <BlindSpotExperimentFollowUpStack />
      <InsightOutcomePromptStack />
      <EmergingPatternsSection
        patterns={acceleration.emergingPatterns}
        reflectionCount={reflectionCount}
        archiveAgeDays={archiveAgeDays}
      />
      <BlindSpotReview
        mainReview={acceleration.mainReview}
        showEmergingHint={acceleration.emergingPatterns.length > 0}
        reflectionCount={reflectionCount}
        archiveAgeDays={archiveAgeDays}
        entries={entries}
      />
      {acceleration.mainReview.kind === "ready" ? (
        <EvolvingViewCard entriesOverride={entries} surface="blind_spots" />
      ) : null}
      <PredictionReviewSection
        report={acceleration.predictionReview}
        reflectionCount={reflectionCount}
        archiveAgeDays={archiveAgeDays}
      />
    </div>
  );
}
