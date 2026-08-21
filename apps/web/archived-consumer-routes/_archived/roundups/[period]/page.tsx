"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { AnimatedReveal } from "@/archived-components/_archived/motion/AnimatedReveal";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { ReflectiveRoundupView } from "@/archived-components/_archived/roundups/ReflectiveRoundupView";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  buildReflectiveRoundup,
  parsePeriodSlug,
} from "@/lib/roundups/reflective-roundups";
import {
  closeRoundupSession,
  recordRoundupLinesShown,
  trackRoundupOpened,
} from "@/lib/roundups/roundup-observation";
import { buildKeyPieces } from "@/lib/roundups/key-pieces";
import { buildRoundupIntentionLinks } from "@/lib/roundups/roundup-intention-links";
import {
  getEmotionalTerritoryById,
} from "@/lib/territories/emotional-territories";
import {
  readActiveTerritoryId,
  resolveTerritoryLabel,
} from "@/lib/territories/territory-preferences";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  KeyPiecesReport,
  ReflectiveRoundup,
  RoundupIntentionLinksReport,
} from "@/types/reflective-roundup";

export default function RoundupPeriodPage() {
  const params = useParams<{ period: string }>();
  const periodSlug = params.period;
  const period = useMemo(() => parsePeriodSlug(periodSlug), [periodSlug]);
  const [roundup, setRoundup] = useState<ReflectiveRoundup | null>(null);
  const [keyPieces, setKeyPieces] = useState<KeyPiecesReport | null>(null);
  const [intentionLinks, setIntentionLinks] = useState<RoundupIntentionLinksReport | null>(null);
  const [territoryLabel, setTerritoryLabel] = useState<string | null>(null);

  useEffect(() => {
    if (!periodSlug || !period) return;
    trackRoundupOpened(periodSlug);
    return () => closeRoundupSession();
  }, [periodSlug, period]);

  useEffect(() => {
    if (!period) {
      setRoundup(null);
      setKeyPieces(null);
      setIntentionLinks(null);
      return;
    }
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      const activeTerritoryId = readActiveTerritoryId();
      const activeTerritory = activeTerritoryId
        ? getEmotionalTerritoryById(entries, activeTerritoryId)
        : null;
      setTerritoryLabel(
        activeTerritory
          ? resolveTerritoryLabel(activeTerritory.id, activeTerritory.defaultLabel)
          : null,
      );
      setRoundup(buildReflectiveRoundup(period));
      setKeyPieces(buildKeyPieces(period, entries, activeTerritoryId));
      setIntentionLinks(buildRoundupIntentionLinks(period));
    });
    return () => cancelAnimationFrame(id);
  }, [period]);

  useEffect(() => {
    if (!periodSlug || !roundup?.lines.length) return;
    recordRoundupLinesShown(periodSlug, roundup.lines);
  }, [periodSlug, roundup?.lines]);

  const loading = period && roundup === null;
  const invalid = !period;

  const periodEyebrow =
    period?.kind === "weekly"
      ? "Weekly roundup"
      : period?.kind === "monthly"
        ? "Monthly roundup"
        : period?.kind === "custom"
          ? "Period review"
          : "Roundup";

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
        {invalid ? (
          <div className="mt-14 space-y-6">
            <h1 className="text-2xl font-semibold text-white">Roundup</h1>
            <p className="text-sm text-muted">That period could not be read.</p>
            <Button asChild variant="secondary">
              <Link href="/roundups">All roundups</Link>
            </Button>
          </div>
        ) : (
          <>
            <AnimatedReveal>
              <p className="text-xs uppercase tracking-[0.2em] text-muted">{periodEyebrow}</p>
              <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
                {period?.label}
              </h1>
            </AnimatedReveal>

            <div className="mt-16">
              {loading ? (
                <Card>
                  <CardContent className="py-16 text-center text-sm text-muted" role="status">
                    Reading this period…
                  </CardContent>
                </Card>
              ) : roundup ? (
                <ReflectiveRoundupView
                  roundup={roundup}
                  keyPieces={keyPieces}
                  intentionLinks={intentionLinks}
                  periodSlug={periodSlug}
                  territoryLabel={territoryLabel}
                />
              ) : null}
            </div>

            {!loading && roundup && !roundup.hasData && !keyPieces?.hasData && !intentionLinks?.hasData ? (
              <div className="mt-10">
                <Button asChild variant="secondary">
                  <Link href="/">Record in this period</Link>
                </Button>
              </div>
            ) : null}
          </>
        )}

        <div className="mt-16 flex flex-wrap gap-4 text-sm">
          <Link href="/roundups" className="text-muted transition-colors hover:text-zinc-200">
            All roundups →
          </Link>
          {period?.kind === "weekly" ? (
            <Link href="/weekly" className="text-muted transition-colors hover:text-zinc-200">
              This week →
            </Link>
          ) : null}
          {period?.kind === "monthly" ? (
            <Link href="/monthly" className="text-muted transition-colors hover:text-zinc-200">
              This month →
            </Link>
          ) : null}
          <Link href="/intentions" className="text-muted transition-colors hover:text-zinc-200">
            Intentions →
          </Link>
        </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
