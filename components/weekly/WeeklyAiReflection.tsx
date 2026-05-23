"use client";

import { useCallback, useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Loader2, RefreshCw, Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildLocalWeeklySummary,
  buildWeeklyReflectionPayload,
  type WeeklyIntelligenceReport,
} from "@/lib/weekly-intelligence";
import {
  getCachedWeeklySummary,
  setCachedWeeklySummary,
} from "@/lib/weekly-summary-cache";

type SummaryState = "idle" | "loading" | "ready" | "error";

interface WeeklyAiReflectionProps {
  report: WeeklyIntelligenceReport;
}

export function WeeklyAiReflection({ report }: WeeklyAiReflectionProps) {
  const [summary, setSummary] = useState<string | null>(null);
  const [state, setState] = useState<SummaryState>("idle");
  const [error, setError] = useState<string | null>(null);

  const loadCached = useCallback(() => {
    const cached = getCachedWeeklySummary(report.weekEndingKey);
    if (cached) {
      setSummary(cached);
      setState("ready");
      return true;
    }
    return false;
  }, [report.weekEndingKey]);

  const generate = useCallback(
    async (force = false) => {
      if (!report.hasData) return;

      if (!force && loadCached()) return;

      setState("loading");
      setError(null);

      try {
        const payload = buildWeeklyReflectionPayload(report);
        const response = await fetch("/api/weekly-reflection", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });

        const data = (await response.json()) as {
          summary?: string;
          error?: string;
        };

        if (!response.ok || !data.summary) {
          throw new Error(data.error ?? "Could not generate weekly reflection");
        }

        setCachedWeeklySummary(report.weekEndingKey, data.summary);
        setSummary(data.summary);
        setState("ready");
      } catch (err) {
        const fallback = buildLocalWeeklySummary(report);
        setSummary(fallback);
        setState("ready");
        setError(
          err instanceof Error
            ? `${err.message} — showing a local summary instead.`
            : "Showing a local summary instead.",
        );
      }
    },
    [loadCached, report],
  );

  useEffect(() => {
    if (!report.hasData) {
      setSummary(buildLocalWeeklySummary(report));
      setState("ready");
      return;
    }

    if (loadCached()) return;

    setState("idle");
    setSummary(null);
  }, [loadCached, report]);

  return (
    <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-fuchsia-500/5">
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-violet-300" />
              <CardTitle className="text-base">Weekly reflection</CardTitle>
            </div>
            <p className="mt-1 text-xs text-zinc-500">
              Weekly intelligence from your local patterns — never stored on a server
            </p>
          </div>
          {report.hasData && state === "ready" ? (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="shrink-0"
              onClick={() => void generate(true)}
            >
              <RefreshCw className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:ml-1">Refresh</span>
            </Button>
          ) : null}
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {state === "idle" && report.hasData ? (
          <div className="space-y-3">
            <p className="text-sm text-zinc-400">
              Generate a personalized paragraph from this week&apos;s emotional
              patterns and how they compare to last week.
            </p>
            <Button
              type="button"
              className="w-full sm:w-auto"
              onClick={() => void generate()}
            >
              <Sparkles className="h-4 w-4" />
              Generate weekly reflection
            </Button>
          </div>
        ) : null}

        {state === "loading" ? (
          <div className="flex items-center gap-3 py-6 text-sm text-zinc-400">
            <Loader2 className="h-5 w-5 animate-spin text-violet-300" />
            Composing your week in words…
          </div>
        ) : null}

        {summary && state !== "loading" ? (
          <motion.p
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-sm leading-relaxed text-zinc-200"
          >
            {summary}
          </motion.p>
        ) : null}

        {error ? <p className="text-xs text-amber-200/80">{error}</p> : null}
      </CardContent>
    </Card>
  );
}
