"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { FirstBlindSpotExampleReviewModal } from "@/archived-components/_archived/product/FirstBlindSpotExampleReviewModal";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  observeActivationBottleneckMilestones,
  trackFirstBlindSpotSimulatorCtaClicked,
  trackFirstBlindSpotSimulatorExampleOpened,
  trackFirstBlindSpotSimulatorShown,
} from "@/lib/product/activation-bottleneck-metrics";
import {
  buildFirstBlindSpotExampleReview,
  buildFirstBlindSpotSimulatorView,
  countEligibleForSimulator,
} from "@/lib/product/first-blind-spot-simulator";
import { FIRST_BLIND_SPOT_SIMULATOR } from "@/lib/product/first-blind-spot-simulator-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FirstBlindSpotSimulatorView } from "@/lib/product/first-blind-spot-simulator";
import type { JournalEntry } from "@/types/journal";

interface FirstBlindSpotSimulatorProps {
  className?: string;
  compact?: boolean;
  entriesOverride?: JournalEntry[];
}

export function FirstBlindSpotSimulator({
  className = "",
  compact = false,
  entriesOverride,
}: FirstBlindSpotSimulatorProps) {
  const entries = useMemo(
    () => entriesOverride ?? getMemoryEligibleEntries(),
    [entriesOverride],
  );
  const [view, setView] = useState<FirstBlindSpotSimulatorView | null>(null);
  const [exampleOpen, setExampleOpen] = useState(false);
  const shownRef = useRef(false);
  const example = useMemo(() => buildFirstBlindSpotExampleReview(), []);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const count = countEligibleForSimulator(entries);
      setView(buildFirstBlindSpotSimulatorView(count));
      observeActivationBottleneckMilestones(count);
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  useEffect(() => {
    if (!view || shownRef.current) return;
    shownRef.current = true;
    trackFirstBlindSpotSimulatorShown(view.reflectionCount);
  }, [view]);

  if (!view) return null;

  const padding = compact ? "p-4" : "p-5";

  function openExample() {
    trackFirstBlindSpotSimulatorExampleOpened(view!.reflectionCount);
    setExampleOpen(true);
  }

  return (
    <>
      <Card
        className={`border border-violet-500/20 bg-violet-950/10 ${className}`}
        data-testid="first-blind-spot-simulator"
      >
        <CardContent className={`space-y-4 ${padding}`}>
          <div>
            <p className="text-sm font-medium text-violet-100">{view.headline}</p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{view.subheadline}</p>
          </div>

          <ul className="space-y-2 text-sm text-zinc-300">
            {view.categories.map((category) => (
              <li key={category} className="flex gap-2">
                <span className="text-emerald-400/90" aria-hidden>
                  ✓
                </span>
                <span>{category}</span>
              </li>
            ))}
          </ul>
          <p className="text-[11px] text-zinc-600">{FIRST_BLIND_SPOT_SIMULATOR.exampleLabel}</p>

          <p className="text-sm font-medium text-amber-100/90">{view.progressLine}</p>

          <div>
            <p className="text-sm text-zinc-400">{view.curiosityTitle}</p>
            <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-zinc-500">
              {view.curiosityBullets.map((bullet) => (
                <li key={bullet}>{bullet}</li>
              ))}
            </ul>
          </div>

          <div className={`flex flex-col gap-2 ${compact ? "" : "sm:flex-row sm:items-center"}`}>
            <Button variant="default" size="sm" asChild className="w-full sm:w-auto">
              <Link
                href="/#recorder"
                onClick={() => trackFirstBlindSpotSimulatorCtaClicked(view.reflectionCount)}
              >
                {FIRST_BLIND_SPOT_SIMULATOR.ctaPrimary}
              </Link>
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="w-full sm:w-auto"
              onClick={openExample}
            >
              {FIRST_BLIND_SPOT_SIMULATOR.ctaSecondary}
            </Button>
          </div>
        </CardContent>
      </Card>

      {exampleOpen ? (
        <FirstBlindSpotExampleReviewModal example={example} onClose={() => setExampleOpen(false)} />
      ) : null}
    </>
  );
}
