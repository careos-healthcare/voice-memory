"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { motion } from "framer-motion";

import { ReflectiveRoundupView } from "@/components/roundups/ReflectiveRoundupView";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
      setRoundup(buildReflectiveRoundup(period));
      setKeyPieces(buildKeyPieces(period));
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

        {invalid ? (
          <div className="mt-16 space-y-6">
            <p className="text-sm text-zinc-500">That period could not be read.</p>
            <Button asChild variant="secondary">
              <Link href="/roundups">All roundups</Link>
            </Button>
          </div>
        ) : (
          <>
            <motion.header
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-2"
            >
              <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">{periodEyebrow}</p>
              <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
                {period?.label}
              </h1>
            </motion.header>

            <div className="mt-16">
              {loading ? (
                <Card>
                  <CardContent className="py-16 text-center text-sm text-zinc-600">
                    Reading this period…
                  </CardContent>
                </Card>
              ) : roundup ? (
                <ReflectiveRoundupView
                  roundup={roundup}
                  keyPieces={keyPieces}
                  intentionLinks={intentionLinks}
                  periodSlug={periodSlug}
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
          <Link href="/roundups" className="text-zinc-500 transition-colors hover:text-zinc-300">
            All roundups →
          </Link>
          {period?.kind === "weekly" ? (
            <Link href="/weekly" className="text-zinc-500 transition-colors hover:text-zinc-300">
              This week →
            </Link>
          ) : null}
          {period?.kind === "monthly" ? (
            <Link href="/monthly" className="text-zinc-500 transition-colors hover:text-zinc-300">
              This month →
            </Link>
          ) : null}
          <Link href="/intentions" className="text-zinc-500 transition-colors hover:text-zinc-300">
            Intentions →
          </Link>
        </div>
      </div>
    </div>
  );
}
